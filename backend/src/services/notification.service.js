import { firebaseKullanilabilir, mesajlasma } from "../config/firebase.js";
import prisma from "../config/database.js";
import logger from "../utils/logger.js";

export const cihazKaydet = async (userId, { fcmToken, platform }) => {
  // Ayni token baska kullaniciya aitse devralinir - cihaz el degistirmis olabilir
  await prisma.deviceToken.upsert({
    where: { fcmToken },
    create: { userId, fcmToken, platform },
    update: { userId, platform },
  });
};

export const cihazSil = async (userId, fcmToken) => {
  await prisma.deviceToken.deleteMany({
    where: { userId, fcmToken },
  });
};

// Bildirim iceriginin ne kadarinin gosterilecegini kullanici ayari belirler
const bildirimIcerigi = (alici, gonderen, mesaj) => {
  let metin = mesaj.content;

  if (mesaj.type === "IMAGE") metin = "Fotograf gonderdi";
  if (mesaj.type === "FILE") metin = "Dosya gonderdi";

  switch (alici.notificationPreview) {
    case "NONE":
      return { title: "Yeni mesaj", body: "Bir mesajiniz var" };
    case "NAME_ONLY":
      return { title: gonderen.fullName, body: "Yeni mesaj" };
    default:
      return { title: gonderen.fullName, body: metin };
  }
};

export const mesajBildirimiGonder = async ({ alici, gonderen, mesaj, conversationId, sessizMi }) => {
  if (!firebaseKullanilabilir()) return;
  if (!alici.notificationsEnabled) return;
  if (sessizMi) return;

  const cihazlar = await prisma.deviceToken.findMany({
    where: { userId: alici.id },
    select: { fcmToken: true },
  });

  if (cihazlar.length === 0) return;

  const { title, body } = bildirimIcerigi(alici, gonderen, mesaj);

  const payload = {
    tokens: cihazlar.map((c) => c.fcmToken),
    notification: { title, body },
    data: {
      conversationId: String(conversationId),
      messageId: String(mesaj.id),
      senderId: String(gonderen.id),
      type: "NEW_MESSAGE",
    },
    android: {
      priority: "high",
      notification: { channelId: "messages", sound: "default" },
    },
  };

  try {
    const sonuc = await mesajlasma().sendEachForMulticast(payload);

    // Gecersiz token'lari temizle
    const silinecekler = [];
    sonuc.responses.forEach((yanit, index) => {
      if (!yanit.success) {
        const kod = yanit.error?.code;
        if (kod === "messaging/registration-token-not-registered" ||
            kod === "messaging/invalid-registration-token") {
          silinecekler.push(payload.tokens[index]);
        }
      }
    });

    if (silinecekler.length > 0) {
      await prisma.deviceToken.deleteMany({ where: { fcmToken: { in: silinecekler } } });
      logger.info(`${silinecekler.length} gecersiz FCM token silindi`);
    }
  } catch (error) {
    logger.error("Bildirim gonderilemedi", { message: error.message });
  }
};