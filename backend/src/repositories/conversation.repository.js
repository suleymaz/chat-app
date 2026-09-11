import prisma from "../config/database.js";

// Iki kullanici arasindaki mevcut sohbeti bulur
export const ikiliSohbetBul = async (userId, digerUserId) => {
  const sohbet = await prisma.conversation.findFirst({
    where: {
      AND: [
        { participants: { some: { userId } } },
        { participants: { some: { userId: digerUserId } } },
      ],
    },
  });

  return sohbet;
};

export const findById = (id) =>
  prisma.conversation.findUnique({
    where: { id },
    include: {
      participants: {
        include: {
          user: {
            select: {
              id: true,
              username: true,
              fullName: true,
              avatarUrl: true,
              isOnline: true,
              lastSeenAt: true,
            },
          },
        },
      },
    },
  });

// Kullanicinin sohbetteki katilim kaydini getirir
export const katilimBul = (conversationId, userId) =>
  prisma.conversationParticipant.findUnique({
    where: { conversationId_userId: { conversationId, userId } },
  });

// Sohbet listesi - son mesaj ve okunmamis sayisi ile birlikte tek sorguda
export const listeGetir = async (userId, { arsivlenmis = false }) => {
  const katilimlar = await prisma.conversationParticipant.findMany({
    where: {
      userId,
      deletedAt: null,
      archivedAt: arsivlenmis ? { not: null } : null,
    },
    include: {
      conversation: {
        include: {
          participants: {
            where: { userId: { not: userId } },
            include: {
              user: {
                select: {
                  id: true,
                  username: true,
                  fullName: true,
                  avatarUrl: true,
                  isOnline: true,
                  lastSeenAt: true,
                },
              },
            },
          },
          messages: {
            take: 1,
            orderBy: { createdAt: "desc" },
            select: {
              id: true,
              content: true,
              type: true,
              senderId: true,
              deletedAt: true,
              createdAt: true,
              deliveredAt: true,
              readAt: true,
            },
          },
        },
      },
    },
    orderBy: { conversation: { lastMessageAt: "desc" } },
  });

  return katilimlar;
};

// Okunmamis mesaj sayisi - lastReadAt sonrasi, baskasindan gelen mesajlar
export const okunmamisSayisi = (conversationId, userId, lastReadAt) =>
  prisma.message.count({
    where: {
      conversationId,
      senderId: { not: userId },
      deletedAt: null,
      createdAt: lastReadAt ? { gt: lastReadAt } : undefined,
    },
  });

export const okunduIsaretle = (conversationId, userId) =>
  prisma.conversationParticipant.update({
    where: { conversationId_userId: { conversationId, userId } },
    data: { lastReadAt: new Date() },
  });

export const arsivle = (conversationId, userId, arsivle) =>
  prisma.conversationParticipant.update({
    where: { conversationId_userId: { conversationId, userId } },
    data: { archivedAt: arsivle ? new Date() : null },
  });

export const sohbetiSil = (conversationId, userId) =>
  prisma.conversationParticipant.update({
    where: { conversationId_userId: { conversationId, userId } },
    data: { deletedAt: new Date() },
  });