import prisma from "../config/database.js";

// Iki kullanici arasinda herhangi bir yonde engel var mi
export const engelVarMi = async (userId, digerUserId) => {
  const kayit = await prisma.block.findFirst({
    where: {
      OR: [
        { blockerId: userId, blockedId: digerUserId },
        { blockerId: digerUserId, blockedId: userId },
      ],
    },
    select: { id: true },
  });

  return kayit !== null;
};

// Aramada ve listelemede haric tutulacak tum id'ler (cift yonlu)
export const iliskisizIdler = async (userId) => {
  const kayitlar = await prisma.block.findMany({
    where: {
      OR: [{ blockerId: userId }, { blockedId: userId }],
    },
    select: { blockerId: true, blockedId: true },
  });

  const idler = new Set();
  for (const k of kayitlar) {
    idler.add(k.blockerId === userId ? k.blockedId : k.blockerId);
  }

  return [...idler];
};

export const findByPair = (blockerId, blockedId) =>
  prisma.block.findUnique({
    where: { blockerId_blockedId: { blockerId, blockedId } },
  });

export const create = (blockerId, blockedId) =>
  prisma.block.create({ data: { blockerId, blockedId } });

export const remove = (blockerId, blockedId) =>
  prisma.block.delete({
    where: { blockerId_blockedId: { blockerId, blockedId } },
  });

export const listBlocked = (userId) =>
  prisma.block.findMany({
    where: { blockerId: userId },
    select: {
      createdAt: true,
      blocked: {
        select: {
          id: true,
          username: true,
          fullName: true,
          avatarUrl: true,
        },
      },
    },
    orderBy: { createdAt: "desc" },
  });