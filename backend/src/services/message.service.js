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
  const katilim = await erisimKontrol(conversationId, userId);

  // Limitten bir fazla cekip devaminin olup olmadigini anliyoruz.
  // Sohbeti silmisse yalnizca silme anindan sonraki mesajlari gorur.
  const mesajlar = await messageRepo.listeGetir({
    conversationId,
    cursor,
    limit: limit + 1,
    sonrasi: katilim.deletedAt,
  });

  const devamVar = mesajlar.length > limit;
  const sayfa = devamVar ? mesajlar.slice(0, limit) : mesajlar;

  const sonMesaj = sayfa[sayfa.length - 1];
  const nextCursor = devamVar && sonMesaj ? messageRepo.imlecUret(sonMesaj) : null;

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
    throw ApiError.badRequest("Sohbette karşı taraf bulunamadı", "NO_RECIPIENT");
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
    throw ApiError.badRequest("Kendinize mesaj gönderemezsiniz", "SELF_MESSAGE");
  }

  const alici = await userRepo.findById(aliciId);

  if (!alici) {
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
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
    throw ApiError.notFound("Mesaj bulunamadı", "MESSAGE_NOT_FOUND");
  }

  if (mesaj.senderId !== userId) {
    throw ApiError.forbidden("Sadece kendi mesajlarınızı silebilirsiniz", "NOT_MESSAGE_OWNER");
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
  const katilim = await erisimKontrol(conversationId, userId);

  const mesajlar = await messageRepo.mesajAra({
    conversationId,
    terim: q,
    limit,
    sonrasi: katilim.deletedAt,
  });

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
    // Alici cevrimiciyse mesaj hemen iletilmis sayilir, bildirime gerek yok.
    // Arada kalmis eski mesajlar da isaretlenir, hepsinin tiki guncellensin.
    const { messageIds, deliveredAt } = await messageRepo.iletildiIsaretle(
      mesaj.conversationId,
      aliciId
    );

    emitters.iletildiYayinla(gonderen.id, {
      conversationId: mesaj.conversationId,
      messageIds: messageIds.length > 0 ? messageIds : [mesaj.id],
      deliveredAt: deliveredAt ?? new Date(),
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

// Yuklenmis dosya varken calisan kontroller icin: kontrol hata verirse
// diskteki dosyayi silip hatayi yeniden firlatir.
const ekliKontrol = async (kontrol, altKlasor, dosya) => {
  try {
    return await kontrol();
  } catch (hata) {
    await fileService.dosyaSil(fileService.urlUret(altKlasor, dosya.filename));
    throw hata;
  }
};

export const gorselGonder = async (gonderen, conversationId, { content, dosya }) => {
  await ekIcerikKontrol(content, "messages", dosya);

  // Sohbet erisimi bu noktada dogrulaniyor ama dosya coktan diske yazilmis
  // oluyor. Hata firlarsa dosya oksuz kalmasin diye temizliyoruz.
  const { karsiTarafId, engelli } = await ekliKontrol(
    () => ekOncesiKontrol(gonderen.id, conversationId),
    "messages",
    dosya
  );

  if (engelli) {
    await fileService.dosyaSil(fileService.urlUret("messages", dosya.filename));
    return sahteMessaj({ conversationId, senderId: gonderen.id, content });
  }

  const ek = await ekBilgisiHazirla({ tip: "IMAGE", altKlasor: "messages", dosya });

  const mesaj = await messageRepo.ekliMesajOlustur({
    conversationId,
    senderId: gonderen.id,
    content,
    type: "IMAGE",
    ek,
  });

  await mesajIletimi(mesaj, karsiTarafId, gonderen, conversationId);

  return mesaj;
};

export const dosyaGonder = async (gonderen, conversationId, { content, dosya }) => {
  await ekIcerikKontrol(content, "files", dosya);

  const { karsiTarafId, engelli } = await ekliKontrol(
    () => ekOncesiKontrol(gonderen.id, conversationId),
    "files",
    dosya
  );

  if (engelli) {
    await fileService.dosyaSil(fileService.urlUret("files", dosya.filename));
    return sahteMessaj({ conversationId, senderId: gonderen.id, content });
  }

  const ek = await ekBilgisiHazirla({ tip: "FILE", altKlasor: "files", dosya });

  const mesaj = await messageRepo.ekliMesajOlustur({
    conversationId,
    senderId: gonderen.id,
    content,
    type: "FILE",
    ek,
  });

  await mesajIletimi(mesaj, karsiTarafId, gonderen, conversationId);

  return mesaj;
};

// Ek mesajlarin aciklama metni multipart govdede geldigi icin zod'dan gecmiyor.
// Metin mesajlariyla ayni siniri burada uyguluyoruz; asarsa yuklenen dosya silinir.
const EK_ICERIK_SINIRI = 4000;
const UUID_DESENI = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function ekIcerikKontrol(content, altKlasor, dosya) {
  if (!content || content.length <= EK_ICERIK_SINIRI) return;

  await fileService.dosyaSil(fileService.urlUret(altKlasor, dosya.filename));

  throw ApiError.badRequest(
    `Mesaj en fazla ${EK_ICERIK_SINIRI} karakter olabilir`,
    "VALIDATION_ERROR"
  );
}

// Yeni sohbet uclarinda alici id'si de multipart govdede geliyor, zod'dan gecmiyor
async function ekAliciKontrol(aliciId, altKlasor, dosya) {
  if (aliciId && UUID_DESENI.test(aliciId)) return;

  await fileService.dosyaSil(fileService.urlUret(altKlasor, dosya.filename));

  throw ApiError.badRequest("Geçersiz kullanıcı kimliği", "VALIDATION_ERROR");
}

// Ilk mesaj gorsel veya dosya oldugunda sohbeti ekle birlikte olusturur.
// Sohbet zaten varsa mevcut sohbete eklenir.
async function yeniSohbetEkGonder(gonderen, { aliciId, content, dosya, tip, altKlasor }) {
  await ekIcerikKontrol(content, altKlasor, dosya);
  await ekAliciKontrol(aliciId, altKlasor, dosya);

  const userId = gonderen.id;

  const ekiSil = () => fileService.dosyaSil(fileService.urlUret(altKlasor, dosya.filename));

  if (userId === aliciId) {
    await ekiSil();
    throw ApiError.badRequest("Kendinize mesaj gönderemezsiniz", "SELF_MESSAGE");
  }

  const alici = await userRepo.findById(aliciId);

  if (!alici) {
    await ekiSil();
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
  }

  const engelli = await blockRepo.engelVarMi(userId, aliciId);

  if (engelli) {
    logger.info(`Engelli kullaniciya ek gonderme denemesi: ${userId} -> ${aliciId}`);
    await ekiSil();
    return {
      conversationId: null,
      message: sahteMessaj({ conversationId: null, senderId: userId, content }),
    };
  }

  const ek = await ekBilgisiHazirla({ tip, altKlasor, dosya });
  const mevcut = await conversationRepo.ikiliSohbetBul(userId, aliciId);

  if (mevcut) {
    const mesaj = await messageRepo.ekliMesajOlustur({
      conversationId: mevcut.id,
      senderId: userId,
      content,
      type: tip,
      ek,
    });

    await mesajIletimi(mesaj, aliciId, gonderen, mevcut.id);
    return { conversationId: mevcut.id, message: mesaj };
  }

  const { sohbet, mesaj } = await messageRepo.sohbetVeEkliMesajOlustur({
    senderId: userId,
    aliciId,
    content,
    type: tip,
    ek,
  });

  await mesajIletimi(mesaj, aliciId, gonderen, sohbet.id);
  return { conversationId: sohbet.id, message: mesaj };
}

// Gorseller kucultulup jpg'ye cevrilir, dosyalar oldugu gibi kaydedilir
async function ekBilgisiHazirla({ tip, altKlasor, dosya }) {
  if (tip === "IMAGE") {
    const bilgi = await fileService.gorselIsle(dosya.path);

    return {
      url: fileService.urlUret(altKlasor, bilgi.dosyaAdi),
      mimeType: bilgi.mimeType,
      sizeBytes: bilgi.sizeBytes,
      width: bilgi.width,
      height: bilgi.height,
    };
  }

  return {
    url: fileService.urlUret(altKlasor, dosya.filename),
    fileName: dosya.originalname,
    mimeType: dosya.mimetype,
    sizeBytes: dosya.size,
  };
}

export const yeniSohbetGorselGonder = (gonderen, { userId, content, dosya }) =>
  yeniSohbetEkGonder(gonderen, {
    aliciId: userId,
    content,
    dosya,
    tip: "IMAGE",
    altKlasor: "messages",
  });

export const yeniSohbetDosyaGonder = (gonderen, { userId, content, dosya }) =>
  yeniSohbetEkGonder(gonderen, {
    aliciId: userId,
    content,
    dosya,
    tip: "FILE",
    altKlasor: "files",
  });

// Ek gonderme oncesi ortak kontroller
async function ekOncesiKontrol(userId, conversationId) {
  await erisimKontrol(conversationId, userId);

  const sohbet = await conversationRepo.findById(conversationId);
  const karsiTaraf = sohbet.participants.find((k) => k.userId !== userId);

  if (!karsiTaraf) {
    throw ApiError.badRequest("Sohbette karşı taraf bulunamadı", "NO_RECIPIENT");
  }

  const engelli = await blockRepo.engelVarMi(userId, karsiTaraf.userId);

  return { karsiTarafId: karsiTaraf.userId, engelli };
}