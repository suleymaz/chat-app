import * as messageRepo from "../repositories/message.repository.js";
import * as conversationRepo from "../repositories/conversation.repository.js";
import * as blockRepo from "../repositories/block.repository.js";
import * as userRepo from "../repositories/user.repository.js";
import { erisimKontrol } from "./conversation.service.js";
import { ApiError } from "../utils/ApiError.js";
import logger from "../utils/logger.js";
import crypto from "crypto";

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
export const gonder = async (userId, conversationId, { content }) => {
  await erisimKontrol(conversationId, userId);

  const sohbet = await conversationRepo.findById(conversationId);
  const karsiTaraf = sohbet.participants.find((k) => k.userId !== userId);

  if (!karsiTaraf) {
    throw ApiError.badRequest("Sohbette karsi taraf bulunamadi", "NO_RECIPIENT");
  }

  const engelli = await blockRepo.engelVarMi(userId, karsiTaraf.userId);

  // Engelli durumda mesaj kaydedilmez, gonderene basarili yanit doner
  if (engelli) {
    logger.info(`Engelli kullaniciya mesaj gonderme denemesi: ${userId} -> ${karsiTaraf.userId}`);
    return sahteMessaj({ conversationId, senderId: userId, content });
  }

  return messageRepo.mesajOlustur({ conversationId, senderId: userId, content });
};

// Yeni sohbet baslatir ve ilk mesaji gonderir
export const yeniSohbetBaslat = async (userId, { userId: aliciId, content }) => {
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

  // Sohbet zaten varsa yeni olusturmaya gerek yok
  const mevcut = await conversationRepo.ikiliSohbetBul(userId, aliciId);

  if (mevcut) {
    const mesaj = await messageRepo.mesajOlustur({
      conversationId: mevcut.id,
      senderId: userId,
      content,
    });

    return { conversationId: mevcut.id, message: mesaj };
  }

  const { sohbet, mesaj } = await messageRepo.sohbetVeMesajOlustur({
    senderId: userId,
    aliciId,
    content,
  });

  return { conversationId: sohbet.id, message: mesaj };
};

export const sil = async (userId, messageId) => {
  const mesaj = await messageRepo.findByIdRaw(messageId);

  if (!mesaj || mesaj.deletedAt) {
    throw ApiError.notFound("Mesaj bulunamadi", "MESSAGE_NOT_FOUND");
  }

  // Sadece kendi mesajini silebilir
  if (mesaj.senderId !== userId) {
    throw ApiError.forbidden("Sadece kendi mesajlarinizi silebilirsiniz", "NOT_MESSAGE_OWNER");
  }

  await erisimKontrol(mesaj.conversationId, userId);

  return messageRepo.softDelete(messageId);
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