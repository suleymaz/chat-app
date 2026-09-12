import * as messageRepo from "../repositories/message.repository.js";
import * as conversationRepo from "../repositories/conversation.repository.js";
import * as blockRepo from "../repositories/block.repository.js";
import * as userRepo from "../repositories/user.repository.js";
import { erisimKontrol } from "./conversation.service.js";
import { ApiError } from "../utils/ApiError.js";
import logger from "../utils/logger.js";
import crypto from "crypto";
import * as emitters from "../sockets/emitters.js";
import { kullaniciBagliMi } from "../config/socket.js";
import * as fileService from "./file.service.js";
import * as notificationService from "./notification.service.js";

// Silinmis mesajlarin icerigi istemciye gonderilmez
const mesajTemizle = (mesaj) => {
  if (!mesaj) return null;

  if (mesaj.deletedAt) {
    return { ...mesaj, content: null, attachments: [] };
  }

  return mesaj;
};

export const listele = async (userId, conversationId, { cursor, limit = 30 }) => {
  await erisimKontrol(conversationId, userId);

  // Limitten bir fazla cekip devaminin olup olmadigini anliyoruz
  const mesajlar = await messageRepo.listeGetir({
    conversationId,
    cursor,
    limit: limit + 1,
  });

  const devamVar = mesajlar.length > limit;
  const sayfa = devamVar ? mesajlar.slice(0, limit) : mesajlar;

  const sonMesaj = sayfa[sayfa.length - 1];
  const nextCursor = devamVar && sonMesaj ? sonMesaj.createdAt.toISOString() : null;

  return {
    items: sayfa.map(mesajTemizle),
    nextCursor,
  };
};

// Mevcut sohbete mesaj gonderir
export const gonder = async (gonderen, conversationId, { content }) => {
  const userId = gonderen.id;

  await erisimKontrol(conversationId, userId);

  const sohbet = await conversationRepo.findById(conversationId);
  const karsiTaraf = sohbet.participants.find((k) => k.userId !== userId);

  if (!karsiTaraf) {
    throw ApiError.badRequest("Sohbette karsi taraf bulunamadi", "NO_RECIPIENT");
  }

  const engelli = await blockRepo.engelVarMi(userId, karsiTaraf.userId);

  if (engelli) {
    logger.info(`Engelli kullaniciya mesaj gonderme denemesi: ${userId} -> ${karsiTaraf.userId}`);
    return sahteMessaj({ conversationId, senderId: userId, content });
  }

  const mesaj = await messageRepo.mesajOlustur({ conversationId, senderId: userId, content });

  await mesajIletimi(mesaj, karsiTaraf.userId, gonderen, conversationId);

  return mesaj;
};

// Yeni sohbet baslatir ve ilk mesaji gonderir
export const yeniSohbetBaslat = async (gonderen, { userId: aliciId, content }) => {
  const userId = gonderen.id;

  if (userId === aliciId) {
    throw ApiError.badRequest("Kendinize mesaj gonderemezsiniz", "SELF_MESSAGE");
  }

  const alici = await userRepo.findById(aliciId);

  if (!alici) {
    throw ApiError.notFound("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  const engelli = await blockRepo.engelVarMi(userId, aliciId);

  if (engelli) {
    logger.info(`Engelli kullaniciya sohbet baslatma denemesi: ${userId} -> ${aliciId}`);
    return {
      conversationId: null,
      message: sahteMessaj({ conversationId: null, senderId: userId, content }),
    };
  }

  const mevcut = await conversationRepo.ikiliSohbetBul(userId, aliciId);

  if (mevcut) {
    const mesaj = await messageRepo.mesajOlustur({
      conversationId: mevcut.id,
      senderId: userId,
      content,
    });

    await mesajIletimi(mesaj, aliciId, gonderen, mevcut.id);

    return { conversationId: mevcut.id, message: mesaj };
  }

  const { sohbet, mesaj } = await messageRepo.sohbetVeMesajOlustur({
    senderId: userId,
    aliciId,
    content,
  });

  await mesajIletimi(mesaj, aliciId, gonderen, sohbet.id);

  return { conversationId: sohbet.id, message: mesaj };
};

export const sil = async (userId, messageId) => {
  const mesaj = await messageRepo.findByIdRaw(messageId);

  if (!mesaj || mesaj.deletedAt) {
    throw ApiError.notFound("Mesaj bulunamadi", "MESSAGE_NOT_FOUND");
  }

  if (mesaj.senderId !== userId) {
    throw ApiError.forbidden("Sadece kendi mesajlarinizi silebilirsiniz", "NOT_MESSAGE_OWNER");
  }

  await erisimKontrol(mesaj.conversationId, userId);

  const silinmis = await messageRepo.softDelete(messageId);

  const sohbet = await conversationRepo.findById(mesaj.conversationId);
  const karsiTaraf = sohbet.participants.find((k) => k.userId !== userId);

  if (karsiTaraf) {
    emitters.mesajSilindiYayinla(karsiTaraf.userId, {
      conversationId: mesaj.conversationId,
      messageId,
    });
  }

  return silinmis;
};

export const ara = async (userId, conversationId, { q, limit = 20 }) => {
  await erisimKontrol(conversationId, userId);

  const mesajlar = await messageRepo.mesajAra({ conversationId, terim: q, limit });

  return mesajlar;
};

// Engelli durumda gonderene donen, veritabanina kaydedilmeyen mesaj nesnesi
function sahteMessaj({ conversationId, senderId, content }) {
  return {
    id: crypto.randomUUID(),
    conversationId,
    senderId,
    content,
    type: "TEXT",
    deliveredAt: null,
    readAt: null,
    deletedAt: null,
    createdAt: new Date(),
    attachments: [],
  };
}

// Mesaji aliciya iletir; alici bagliysa socket, degilse FCM kullanilir
async function mesajIletimi(mesaj, aliciId, gonderen, conversationId) {
  emitters.yeniMesajYayinla(aliciId, mesaj);

  if (kullaniciBagliMi(aliciId)) {
    // Alici cevrimiciyse mesaj hemen iletilmis sayilir, bildirime gerek yok
    const iletilmeZamani = new Date();

    await messageRepo.iletildiIsaretle(mesaj.conversationId, aliciId);

    emitters.iletildiYayinla(gonderen.id, {
      conversationId: mesaj.conversationId,
      messageIds: [mesaj.id],
      deliveredAt: iletilmeZamani,
    });

    return;
  }

  // Alici bagli degilse bildirim gonderilir
  const alici = await userRepo.findById(aliciId);
  const katilim = await conversationRepo.katilimBul(conversationId, aliciId);

  await notificationService.mesajBildirimiGonder({
    alici,
    gonderen,
    mesaj,
    conversationId,
    sessizMi: katilim?.isMuted ?? false,
  });
}

export const gorselGonder = async (gonderen, conversationId, { content, dosya }) => {
  const { karsiTarafId, engelli } = await ekOncesiKontrol(gonderen.id, conversationId);

  if (engelli) {
    await fileService.dosyaSil(fileService.urlUret("messages", dosya.filename));
    return sahteMessaj({ conversationId, senderId: gonderen.id, content });
  }

  const bilgi = await fileService.gorselIsle(dosya.path);
  const url = fileService.urlUret("messages", dosya.filename);

  const mesaj = await messageRepo.ekliMesajOlustur({
    conversationId,
    senderId: gonderen.id,
    content,
    type: "IMAGE",
    ek: {
      url,
      mimeType: "image/jpeg",
      sizeBytes: bilgi.sizeBytes,
      width: bilgi.width,
      height: bilgi.height,
    },
  });

  await mesajIletimi(mesaj, karsiTarafId, gonderen, conversationId);

  return mesaj;
};

export const dosyaGonder = async (gonderen, conversationId, { content, dosya }) => {
  const { karsiTarafId, engelli } = await ekOncesiKontrol(gonderen.id, conversationId);

  if (engelli) {
    await fileService.dosyaSil(fileService.urlUret("files", dosya.filename));
    return sahteMessaj({ conversationId, senderId: gonderen.id, content });
  }

  const url = fileService.urlUret("files", dosya.filename);

  const mesaj = await messageRepo.ekliMesajOlustur({
    conversationId,
    senderId: gonderen.id,
    content,
    type: "FILE",
    ek: {
      url,
      fileName: dosya.originalname,
      mimeType: dosya.mimetype,
      sizeBytes: dosya.size,
    },
  });

  await mesajIletimi(mesaj, karsiTarafId, gonderen, conversationId);

  return mesaj;
};

// Ek gonderme oncesi ortak kontroller
async function ekOncesiKontrol(userId, conversationId) {
  await erisimKontrol(conversationId, userId);

  const sohbet = await conversationRepo.findById(conversationId);
  const karsiTaraf = sohbet.participants.find((k) => k.userId !== userId);

  if (!karsiTaraf) {
    throw ApiError.badRequest("Sohbette karsi taraf bulunamadi", "NO_RECIPIENT");
  }

  const engelli = await blockRepo.engelVarMi(userId, karsiTaraf.userId);

  return { karsiTarafId: karsiTaraf.userId, engelli };
}