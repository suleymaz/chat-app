import prisma from '../config/database.js';

export const create = ({ userId, tokenHash, expiresAt }) =>
  prisma.refreshToken.create({ data: { userId, tokenHash, expiresAt } });

export const findByHash = (tokenHash) =>
  prisma.refreshToken.findUnique({ where: { tokenHash } });

export const revokeById = (id) =>
  prisma.refreshToken.update({
    where: { id },
    data: { revokedAt: new Date() },
  });

export const revokeAllForUser = (userId) =>
  prisma.refreshToken.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });

export const deleteExpired = () =>
  prisma.refreshToken.deleteMany({
    where: { expiresAt: { lt: new Date() } },
  });