import prisma from "../config/database.js";

export const mesajSelect = {
  id: true,
  conversationId: true,
  senderId: true,
  content: true,
  type: true,
  deliveredAt: true,
  readAt: true,
  deletedAt: true,
  createdAt: true,
  attachments: {
    select: {
      id: true,
      url: true,
      fileName: true,
      mimeType: true,
      sizeBytes: true,
      width: true,
      height: true,
    },
  },
};

// Imlec "ISO tarih|mesaj id" seklinde tutulur. Sadece tarihe bakmak, ayni
// milisaniyede olusan mesajlarda sayfa sinirinda kayba yol aciyordu.
export const imlecUret = (mesaj) => `${mesaj.createdAt.toISOString()}|${mesaj.id}`;

const imleciCoz = (cursor) => {
  if (!cursor) return null;

  const [tarihMetni, id] = String(cursor).split("|");
  const olusturulma = new Date(tarihMetni);

  if (Number.isNaN(olusturulma.getTime())) return null;

  return { olusturulma, id: id || null };
};

// Cursor tabanli sayfalama - eskiye dogru gider
export const listeGetir = ({ conversationId, cursor, limit }) => {
  const imlec = imleciCoz(cursor);

  return prisma.message.findMany({
    where: {
      conversationId,
      ...(imlec
        ? {
            OR: [
              { createdAt: { lt: imlec.olusturulma } },
              ...(imlec.id
                ? [{ createdAt: imlec.olusturulma, id: { lt: imlec.id } }]
                : []),
            ],
          }
        : {}),
    },
    select: mesajSelect,
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    take: limit,
  });
};

export const findByIdRaw = (id) =>
  prisma.message.findUnique({ where: { id } });

// Karsi taraf sohbeti silmisse yeni mesajla birlikte sohbet ona geri gelir.
// Aksi halde mesaj veritabanina yazilir ama alici onu hicbir zaman goremez.
const katilimiCanlandir = (tx, conversationId, senderId) =>
  tx.conversationParticipant.updateMany({
    where: { conversationId, userId: { not: senderId }, deletedAt: { not: null } },
    data: { deletedAt: null },
  });

// Mesaj gonderme - sohbet yoksa olusturulur, hepsi tek transaction icinde
export const mesajOlustur = ({ conversationId, senderId, content, type = "TEXT" }) =>
  prisma.$transaction(async (tx) => {
    const mesaj = await tx.message.create({
      data: { conversationId, senderId, content, type },
      select: mesajSelect,
    });

    await tx.conversation.update({
      where: { id: conversationId },
      data: { lastMessageAt: mesaj.createdAt },
    });

    await katilimiCanlandir(tx, conversationId, senderId);

    return mesaj;
  });

// Sohbet ve mesaji birlikte olusturur - ilk mesaj icin
export const sohbetVeMesajOlustur = ({ senderId, aliciId, content, type = "TEXT" }) =>
  prisma.$transaction(async (tx) => {
    const sohbet = await tx.conversation.create({
      data: {
        participants: {
          create: [{ userId: senderId }, { userId: aliciId }],
        },
      },
    });

    const mesaj = await tx.message.create({
      data: { conversationId: sohbet.id, senderId, content, type },
      select: mesajSelect,
    });

    await tx.conversation.update({
      where: { id: sohbet.id },
      data: { lastMessageAt: mesaj.createdAt },
    });

    return { sohbet, mesaj };
  });

export const softDelete = (id) =>
  prisma.message.update({
    where: { id },
    data: { deletedAt: new Date(), content: null },
    select: mesajSelect,
  });

// Iletilmemis mesajlari isaretler ve hangi id'lerin degistigini doner.
// Gonderene tik bilgisini tam yayinlayabilmek icin id listesi gerekiyor.
export const iletildiIsaretle = async (conversationId, aliciId) => {
  const bekleyenler = await prisma.message.findMany({
    where: {
      conversationId,
      senderId: { not: aliciId },
      deliveredAt: null,
    },
    select: { id: true },
  });

  if (bekleyenler.length === 0) {
    return { messageIds: [], deliveredAt: null };
  }

  const deliveredAt = new Date();
  const messageIds = bekleyenler.map((m) => m.id);

  await prisma.message.updateMany({
    where: { id: { in: messageIds } },
    data: { deliveredAt },
  });

  return { messageIds, deliveredAt };
};

export const okunduIsaretle = (conversationId, aliciId) =>
  prisma.message.updateMany({
    where: {
      conversationId,
      senderId: { not: aliciId },
      readAt: null,
    },
    data: { readAt: new Date() },
  });

// Sohbet icinde mesaj arama
export const mesajAra = ({ conversationId, terim, limit }) =>
  prisma.message.findMany({
    where: {
      conversationId,
      deletedAt: null,
      content: { contains: terim, mode: "insensitive" },
    },
    select: mesajSelect,
    orderBy: { createdAt: "desc" },
    take: limit,
  });


  // Gorsel mesaji - mesaj ve eki tek transaction icinde olusturulur
// Ekli mesaj olusturur - gorsel veya dosya
export const ekliMesajOlustur = ({ conversationId, senderId, content, type, ek }) =>
  prisma.$transaction(async (tx) => {
    const mesaj = await tx.message.create({
      data: {
        conversationId,
        senderId,
        content: content || null,
        type,
        attachments: {
          create: {
            url: ek.url,
            fileName: ek.fileName ?? null,
            mimeType: ek.mimeType,
            sizeBytes: ek.sizeBytes,
            width: ek.width ?? null,
            height: ek.height ?? null,
          },
        },
      },
      select: mesajSelect,
    });

    await tx.conversation.update({
      where: { id: conversationId },
      data: { lastMessageAt: mesaj.createdAt },
    });

    await katilimiCanlandir(tx, conversationId, senderId);

    return mesaj;
  });