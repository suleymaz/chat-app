import * as conversationRepo from "../repositories/conversation.repository.js";
import * as messageRepo from "../repositories/message.repository.js";
import * as blockRepo from "../repositories/block.repository.js";
import * as userRepo from "../repositories/user.repository.js";
import { ApiError } from "../utils/ApiError.js";
import * as emitters from "../sockets/emitters.js";

// Iki tarihten sonrakini doner - null degerler yok sayilir
const enGecTarih = (a, b) => {
  if (!a) return b ?? null;
  if (!b) return a;
  return a > b ? a : b;
};

// Kullanicinin sohbete erisim yetkisi var mi kontrol eder.
// deletedAt "sohbeti sildigi an"dir, katilimi sonlandirmaz: kullanici sohbette
// kalir ama o andan onceki mesajlari goremez. Donen katilim kaydindaki
// deletedAt, mesaj sorgularinda kesme noktasi olarak kullanilir.
const erisimKontrol = async (conversationId, userId) => {
  const katilim = await conversationRepo.katilimBul(conversationId, userId);

  if (!katilim) {
    throw ApiError.notFound("Sohbet bulunamadı", "CONVERSATION_NOT_FOUND");
  }

  return katilim;
};

// Sohbet listesi - her sohbet icin son mesaj, okunmamis sayisi ve karsi kullanici
export const listele = async (userId, { archived = false } = {}) => {
  const tumKatilimlar = await conversationRepo.listeGetir(userId, { arsivlenmis: archived });

  // Silinmis sohbetler yalnizca silme anindan sonra mesaj geldiyse listede yer alir
  const katilimlar = tumKatilimlar.filter((katilim) => {
    if (!katilim.deletedAt) return true;

    const sonMesaj = katilim.conversation.messages[0];
    return sonMesaj != null && sonMesaj.createdAt > katilim.deletedAt;
  });

  // Okunmamis sayilari tek sorguda gelir - sohbet basina ayri count atmiyoruz.
  // Esik, okundu bilgisi ile silme ani arasindaki en gec tarihtir.
  const okunmamisHarita = await conversationRepo.okunmamisSayilari(
    userId,
    katilimlar.map((k) => ({
      conversationId: k.conversationId,
      lastReadAt: enGecTarih(k.lastReadAt, k.deletedAt),
    }))
  );

  return katilimlar.map((katilim) => {
    const sohbet = katilim.conversation;
    const karsiTaraf = sohbet.participants[0]?.user ?? null;
    const sonMesaj = sohbet.messages[0] ?? null;

    return {
      id: sohbet.id,
      user: karsiTaraf,
      lastMessage: sonMesaj,
      unreadCount: okunmamisHarita.get(sohbet.id) ?? 0,
      isMuted: katilim.isMuted,
      isArchived: katilim.archivedAt !== null,
      lastMessageAt: sohbet.lastMessageAt,
    };
  });
};

// Sohbet detayi
export const detay = async (userId, conversationId) => {
  const katilim = await erisimKontrol(conversationId, userId);

  const sohbet = await conversationRepo.findById(conversationId);
  const karsiTaraf = sohbet.participants.find((k) => k.userId !== userId)?.user ?? null;

  // Sadece "ben engelledim mi" bilgisi doner. Karsi tarafin beni engelleyip
  // engellemedigi bilgisi verilmez, engellenen kisi bunu ogrenmemeli.
  const engel = karsiTaraf ? await blockRepo.findByPair(userId, karsiTaraf.id) : null;

  return {
    id: sohbet.id,
    user: karsiTaraf,
    isBlocked: engel !== null,
    isMuted: katilim.isMuted,
    lastMessageAt: sohbet.lastMessageAt,
    createdAt: sohbet.createdAt,
  };
};

// Bir kullaniciyla olan sohbeti bulur, yoksa null doner
export const kullaniciylaSohbet = async (userId, digerUserId) => {
  if (userId === digerUserId) {
    throw ApiError.badRequest("Kendinizle sohbet başlatamazsınız", "SELF_CONVERSATION");
  }

  const hedef = await userRepo.findById(digerUserId);

  if (!hedef) {
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
  }

  const engelli = await blockRepo.engelVarMi(userId, digerUserId);

  if (engelli) {
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
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
  const katilim = await erisimKontrol(conversationId, userId);

  await conversationRepo.okunduIsaretle(conversationId, userId);
  await messageRepo.okunduIsaretle(conversationId, userId, katilim.deletedAt);


  // Karsi tarafa mesajlarinin okundugunu bildir
  const sohbet = await conversationRepo.findById(conversationId);
  const karsiTaraf = sohbet.participants.find((k) => k.userId !== userId);

  if (karsiTaraf) {
    emitters.okunduYayinla(karsiTaraf.userId, {
      conversationId,
      readAt: new Date(),
    });
  }

};

export const arsivle = async (userId, conversationId, archived) => {
  await erisimKontrol(conversationId, userId);
  await conversationRepo.arsivle(conversationId, userId, archived);
};

export const sessizeAl = async (userId, conversationId, muted) => {
  await erisimKontrol(conversationId, userId);
  await conversationRepo.sessizeAl(conversationId, userId, muted);
};

export const sil = async (userId, conversationId) => {
  await erisimKontrol(conversationId, userId);
  await conversationRepo.sohbetiSil(conversationId, userId);
};

export { erisimKontrol };