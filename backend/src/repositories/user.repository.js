import prisma from '../config/database.js';

export const publicUserSelect = {
  id: true,
  username: true,
  email: true,
  phone: true,
  fullName: true,
  avatarUrl: true,
  bio: true,
  isOnline: true,
  lastSeenAt: true,
  notificationsEnabled: true,
  notificationPreview: true,
  createdAt: true,
};

export const findById = (id) =>
  prisma.user.findUnique({ where: { id }, select: publicUserSelect });

export const findByIdWithPassword = (id) =>
  prisma.user.findUnique({ where: { id } });

export const findByEmail = (email) =>
  prisma.user.findUnique({ where: { email } });

export const findByUsername = (username) =>
  prisma.user.findUnique({ where: { username } });

export const findByLoginIdentifier = (identifier) =>
  prisma.user.findFirst({
    where: {
      OR: [
        { email: identifier },
        { username: identifier },
        { phone: identifier },
      ],
    },
  });

export const create = (data) =>
  prisma.user.create({ data, select: publicUserSelect });

export const existsByUniqueFields = ({ username, email, phone }) =>
  prisma.user.findFirst({
    where: { OR: [{ username }, { email }, { phone }] },
    select: { id: true, username: true, email: true, phone: true },
  });