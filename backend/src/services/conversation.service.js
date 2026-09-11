import * as conversationRepo from "../repositories/conversation.repository.js";
import * as messageRepo from "../repositories/message.repository.js";
import * as blockRepo from "../repositories/block.repository.js";
import * as userRepo from "../repositories/user.repository.js";
import { ApiError } from "../utils/ApiError.js";

// Kullanicinin sohbete erisim yetkisi var mi kontrol eder
const erisimKontrol = async (conversationId, userId) => {
  const katilim = await conversationRepo.katilimBul(conversationId, userId);

  if (!katilim || katilim.deletedAt) {
    throw ApiError.notFound("Sohbet bulunamadi", "CONVERSATION_NOT_FOUND");
  }

  return katilim;
};

// Sohbet listesi - her sohbet icin son mesaj, okunmamis sayisi ve karsi kullanici
export const listele = async (userId, { archived = false } = {}) => {
  const katilimlar = await conversationRepo.listeGetir(userId, { arsivlenmis: archived });

  const sohbetler = await Promise.all(
    katilimlar.map(async (katilim) => {
      const sohbet = katilim.conversation;
      const karsiTaraf = sohbet.participants[0]?.user ?? null;
      const sonMesaj = sohbet.messages[0] ?? null;

      const okunmamis = await conversationRepo.okunmamisSayisi(
        sohbet.id,
        userId,
        katilim.lastReadAt
      );

      return {
        id: sohbet.id,
        user: karsiTaraf,
        lastMessage: sonMesaj,
        unreadCount: okunmamis,
        isMuted: katilim.isMuted,
        isArchived: katilim.archivedAt !== null,
        lastMessageAt: sohbet.lastMessageAt,
      };
    })
  );

  return sohbetler;
};

// Sohbet detayi
export const detay = async (userId, conversationId) => {
  await erisimKontrol(conversationId, userId);

  const sohbet = await conversationRepo.findById(conversationId);
  const karsiTaraf = sohbet.participants.find((k) => k.userId !== userId)?.user ?? null;

  return {
    id: sohbet.id,
    user: karsiTaraf,
    lastMessageAt: sohbet.lastMessageAt,
    createdAt: sohbet.createdAt,
  };
};

// Bir kullaniciyla olan sohbeti bulur, yoksa null doner
export const kullaniciylaSohbet = async (userId, digerUserId) => {
  if (userId === digerUserId) {
    throw ApiError.badRequest("Kendinizle sohbet baslatamazsiniz", "SELF_CONVERSATION");
  }

  const hedef = await userRepo.findById(digerUserId);

  if (!hedef) {
    throw ApiError.notFound("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  const engelli = await blockRepo.engelVarMi(userId, digerUserId);

  if (engelli) {
    throw ApiError.notFound("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  const sohbet = await conversationRepo.ikiliSohbetBul(userId, digerUserId);

  if (!sohbet) {
    return { id: null, user: hedef, lastMessageAt: null, isNew: true };
  }

  return {
    id: sohbet.id,
    user: hedef,
    lastMessageAt: sohbet.lastMessageAt,
    isNew: false,
  };
};

export const okunduIsaretle = async (userId, conversationId) => {
  await erisimKontrol(conversationId, userId);

  await conversationRepo.okunduIsaretle(conversationId, userId);
  await messageRepo.okunduIsaretle(conversationId, userId);
};

export const arsivle = async (userId, conversationId, archived) => {
  await erisimKontrol(conversationId, userId);
  await conversationRepo.arsivle(conversationId, userId, archived);
};

export const sil = async (userId, conversationId) => {
  await erisimKontrol(conversationId, userId);
  await conversationRepo.sohbetiSil(conversationId, userId);
};

export { erisimKontrol };