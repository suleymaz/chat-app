import { Server } from "socket.io";
import { verifyAccessToken } from "../utils/token.js";
import * as userRepo from "../repositories/user.repository.js";
import * as conversationRepo from "../repositories/conversation.repository.js";
import { corsOrigin } from "./cors.js";
import logger from "../utils/logger.js";

let io = null;

// Bagli kullanicilarin socket sayilari - coklu cihaz destegi icin
const bagliKullanicilar = new Map();

// userId -> socket id listesi. Room yerine dogrudan socket'e yayin yapiyoruz
const kullaniciSocketleri = new Map();

export const initSocket = (httpServer) => {
  if (io) {
    logger.warn("Socket.IO zaten baslatilmis, tekrar baslatilmiyor");
    return io;
  }

    io = new Server(httpServer, {
    cors: {
      origin: corsOrigin(),
      methods: ["GET", "POST"],
    },
    pingTimeout: 60000,
    transports: ["websocket"],
  });

  // Baglanti kurulmadan once token dogrulanir
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;

      if (!token) {
        return next(new Error("Token gerekli"));
      }

      const payload = verifyAccessToken(token);
      const kullanici = await userRepo.findById(payload.sub);

      if (!kullanici) {
        return next(new Error("Kullanici bulunamadi"));
      }

      socket.userId = kullanici.id;
      socket.username = kullanici.username;
      next();
    } catch (error) {
      logger.warn(`Socket auth basarisiz: ${error.message}`);
      next(new Error("Gecersiz token"));
    }
  });

  io.on("connection", (socket) => {
    baglantiKur(socket);
  });

  return io;
};

const baglantiKur = async (socket) => {
  const { userId, username } = socket;

  socket.join(`user:${userId}`);

  const mevcutSoketler = kullaniciSocketleri.get(userId) ?? [];
  kullaniciSocketleri.set(userId, [...mevcutSoketler, socket.id]);
  const oncekiSayi = bagliKullanicilar.get(userId) ?? 0;
  bagliKullanicilar.set(userId, oncekiSayi + 1);

  // Ilk baglanti ise cevrimici olarak isaretle
  if (oncekiSayi === 0) {
    await userRepo.update(userId, { isOnline: true });
    socket.broadcast.emit("user:online", { userId });
    logger.info(`Kullanici cevrimici: ${username}`);

    // Cevrimdisiyken gelen mesajlar simdi iletilmis sayilir
    await bekleyenMesajlariIlet(userId);
  }

  // Sohbet odasina katilma - yaziyor gostergesi icin.
  // Sadece sohbetin katilimcisi odaya girebilir.
  socket.on("conversation:join", async ({ conversationId }) => {
    if (!conversationId) return;

    const katilim = await conversationRepo.katilimBul(conversationId, userId);

    if (!katilim || katilim.deletedAt) {
      logger.warn(`Yetkisiz sohbet odasi denemesi: ${username} -> ${conversationId}`);
      return;
    }

    socket.join(`conversation:${conversationId}`);
  });

  socket.on("conversation:leave", ({ conversationId }) => {
    if (conversationId) {
      socket.leave(`conversation:${conversationId}`);
    }
  });

  // Yaziyor gostergesi - sadece o sohbet odasindakilere gider
  socket.on("typing:start", ({ conversationId }) => {
    socket.to(`conversation:${conversationId}`).emit("typing", {
      conversationId,
      userId,
      isTyping: true,
    });
  });

  socket.on("typing:stop", ({ conversationId }) => {
    socket.to(`conversation:${conversationId}`).emit("typing", {
      conversationId,
      userId,
      isTyping: false,
    });
  });

  socket.on("disconnect", async (sebep) => {
    const soketler = (kullaniciSocketleri.get(userId) ?? []).filter((id) => id !== socket.id);

    if (soketler.length === 0) {
      kullaniciSocketleri.delete(userId);
    } else {
      kullaniciSocketleri.set(userId, soketler);
    }

    const kalanSayi = (bagliKullanicilar.get(userId) ?? 1) - 1;

    if (kalanSayi <= 0) {
      bagliKullanicilar.delete(userId);
      const simdi = new Date();
      await userRepo.update(userId, { isOnline: false, lastSeenAt: simdi });
      socket.broadcast.emit("user:offline", { userId, lastSeenAt: simdi });
      logger.info(`Kullanici cevrimdisi: ${username}`);
    } else {
      bagliKullanicilar.set(userId, kalanSayi);
    }
  });
};

export const getIO = () => {
  if (!io) {
    throw new Error("Socket.IO baslatilmamis");
  }
  return io;
};

// Kullanici su an bagli mi - FCM gonderilip gonderilmeyecegine karar vermek icin
export const kullaniciBagliMi = (userId) => bagliKullanicilar.has(userId);

// Bir kullanicinin acik socket id'leri
export const kullaniciSocketIdleri = (userId) => kullaniciSocketleri.get(userId) ?? [];

// Kullanici baglandiginda, o bagli degilken gelen mesajlari iletildi olarak isaretler
const bekleyenMesajlariIlet = async (userId) => {
  const { default: prisma } = await import("./database.js");
  const emitters = await import("../sockets/emitters.js");

  // Kullanicinin katildigi sohbetlerdeki, baskasindan gelen ve henuz iletilmemis mesajlar
  const bekleyenler = await prisma.message.findMany({
    where: {
      deliveredAt: null,
      senderId: { not: userId },
      conversation: {
        participants: { some: { userId } },
      },
    },
    select: { id: true, conversationId: true, senderId: true },
  });

  if (bekleyenler.length === 0) return;

  const simdi = new Date();

  await prisma.message.updateMany({
    where: { id: { in: bekleyenler.map((m) => m.id) } },
    data: { deliveredAt: simdi },
  });

  // Gonderenlere haber ver - sohbet bazinda gruplayip tek olay gonderiyoruz
  const gonderenBazinda = new Map();

  for (const mesaj of bekleyenler) {
    const anahtar = `${mesaj.senderId}|${mesaj.conversationId}`;
    const mevcut = gonderenBazinda.get(anahtar) ?? [];
    gonderenBazinda.set(anahtar, [...mevcut, mesaj.id]);
  }

  for (const [anahtar, messageIds] of gonderenBazinda) {
    const [gonderenId, conversationId] = anahtar.split("|");
    emitters.iletildiYayinla(gonderenId, {
      conversationId,
      messageIds,
      deliveredAt: simdi,
    });
  }

  logger.info(`${bekleyenler.length} bekleyen mesaj iletildi olarak isaretlendi: ${userId}`);
};