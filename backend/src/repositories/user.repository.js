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

  // Kullanici adi, ad soyad, e-posta veya telefona gore arama
export const search = ({ terim, haricTutulanIdler, limit }) =>
  prisma.user.findMany({
    where: {
      AND: [
        { id: { notIn: haricTutulanIdler } },
        {
          OR: [
            { username: { contains: terim, mode: "insensitive" } },
            { fullName: { contains: terim, mode: "insensitive" } },
            { email: { equals: terim, mode: "insensitive" } },
            { phone: { equals: terim } },
          ],
        },
      ],
    },
    select: {
      id: true,
      username: true,
      fullName: true,
      avatarUrl: true,
      bio: true,
      isOnline: true,
      lastSeenAt: true,
    },
    take: limit,
    orderBy: { username: "asc" },
  });

export const update = (id, data) =>
  prisma.user.update({ where: { id }, data, select: publicUserSelect });

export const updatePassword = (id, passwordHash) =>
  prisma.user.update({ where: { id }, data: { passwordHash } });

// Baskasinin profilini gorurken donen alanlar - e-posta ve telefon gizli
export const findProfileById = (id) =>
  prisma.user.findUnique({
    where: { id },
    select: {
      id: true,
      username: true,
      fullName: true,
      avatarUrl: true,
      bio: true,
      isOnline: true,
      lastSeenAt: true,
      createdAt: true,
    },
  });