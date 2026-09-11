import { Server } from "socket.io";
import { verifyAccessToken } from "../utils/token.js";
import * as userRepo from "../repositories/user.repository.js";
import logger from "../utils/logger.js";

let io = null;

// Bagli kullanicilarin socket sayilari - coklu cihaz destegi icin
const bagliKullanicilar = new Map();

export const initSocket = (httpServer) => {
  io = new Server(httpServer, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
    pingTimeout: 60000,
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

  const oncekiSayi = bagliKullanicilar.get(userId) ?? 0;
  bagliKullanicilar.set(userId, oncekiSayi + 1);

  // Ilk baglanti ise cevrimici olarak isaretle
  if (oncekiSayi === 0) {
    await userRepo.update(userId, { isOnline: true });
    socket.broadcast.emit("user:online", { userId });
    logger.info(`Kullanici cevrimici: ${username}`);
  }

  // Sohbet odasina katilma - yaziyor gostergesi icin
  socket.on("conversation:join", ({ conversationId }) => {
    if (conversationId) {
      socket.join(`conversation:${conversationId}`);
    }
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

  socket.on("disconnect", async () => {
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