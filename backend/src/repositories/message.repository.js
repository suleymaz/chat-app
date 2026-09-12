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

// Cursor tabanli sayfalama - eskiye dogru gider
export const listeGetir = ({ conversationId, cursor, limit }) =>
  prisma.message.findMany({
    where: {
      conversationId,
      ...(cursor ? { createdAt: { lt: new Date(cursor) } } : {}),
    },
    select: mesajSelect,
    orderBy: { createdAt: "desc" },
    take: limit,
  });

export const findById = (id) =>
  prisma.message.findUnique({ where: id ? { id } : undefined, select: mesajSelect });

export const findByIdRaw = (id) =>
  prisma.message.findUnique({ where: { id } });

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

export const iletildiIsaretle = (conversationId, aliciId) =>
  prisma.message.updateMany({
    where: {
      conversationId,
      senderId: { not: aliciId },
      deliveredAt: null,
    },
    data: { deliveredAt: new Date() },
  });

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

    return mesaj;
  });