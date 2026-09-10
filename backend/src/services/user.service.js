import * as userRepo from "../repositories/user.repository.js";
import * as blockRepo from "../repositories/block.repository.js";
import * as tokenRepo from "../repositories/refreshToken.repository.js";
import { hashPassword, comparePassword } from "../utils/password.js";
import { ApiError } from "../utils/ApiError.js";
import logger from "../utils/logger.js";

export const getMyProfile = async (userId) => {
  const kullanici = await userRepo.findById(userId);

  if (!kullanici) {
    throw ApiError.notFound("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  return kullanici;
};

export const updateProfile = async (userId, veriler) => {
  // Kullanici adi degisiyorsa baskasi tarafindan alinmis mi kontrol et
  if (veriler.username) {
    const mevcut = await userRepo.findByUsername(veriler.username);

    if (mevcut && mevcut.id !== userId) {
      throw ApiError.conflict("Bu kullanici adi zaten kullaniliyor", "USERNAME_TAKEN");
    }
  }

  return userRepo.update(userId, veriler);
};

export const changePassword = async (userId, { currentPassword, newPassword }) => {
  const kullanici = await userRepo.findByIdWithPassword(userId);

  if (!kullanici) {
    throw ApiError.notFound("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  const dogruMu = await comparePassword(currentPassword, kullanici.passwordHash);

  if (!dogruMu) {
    throw ApiError.unauthorized("Mevcut sifre hatali", "INVALID_CURRENT_PASSWORD");
  }

  const yeniHash = await hashPassword(newPassword);
  await userRepo.updatePassword(userId, yeniHash);

  // Sifre degistiginde tum oturumlar sonlandirilir
  await tokenRepo.revokeAllForUser(userId);

  logger.info(`Sifre degistirildi: userId=${userId}`);
};

export const searchUsers = async (userId, { q, limit = 20 }) => {
  // Engelli iliskisi olan kullanicilar ve kullanicinin kendisi haric tutulur
  const haricTutulanIdler = await blockRepo.iliskisizIdler(userId);
  haricTutulanIdler.push(userId);

  return userRepo.search({ terim: q, haricTutulanIdler, limit });
};

export const getUserProfile = async (userId, hedefId) => {
  if (userId === hedefId) {
    return userRepo.findById(userId);
  }

  const engelli = await blockRepo.engelVarMi(userId, hedefId);

  if (engelli) {
    throw ApiError.notFound("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  const profil = await userRepo.findProfileById(hedefId);

  if (!profil) {
    throw ApiError.notFound("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  return profil;
};

export const blockUser = async (userId, hedefId) => {
  if (userId === hedefId) {
    throw ApiError.badRequest("Kendinizi engelleyemezsiniz", "SELF_BLOCK");
  }

  const hedef = await userRepo.findById(hedefId);

  if (!hedef) {
    throw ApiError.notFound("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  const mevcut = await blockRepo.findByPair(userId, hedefId);

  if (mevcut) {
    throw ApiError.conflict("Bu kullanici zaten engellenmis", "ALREADY_BLOCKED");
  }

  await blockRepo.create(userId, hedefId);
  logger.info(`Kullanici engellendi: ${userId} -> ${hedefId}`);
};

export const unblockUser = async (userId, hedefId) => {
  const mevcut = await blockRepo.findByPair(userId, hedefId);

  if (!mevcut) {
    throw ApiError.notFound("Bu kullanici engellenmemis", "NOT_BLOCKED");
  }

  await blockRepo.remove(userId, hedefId);
  logger.info(`Engel kaldirildi: ${userId} -> ${hedefId}`);
};

export const getBlockedUsers = async (userId) => {
  const kayitlar = await blockRepo.listBlocked(userId);

  return kayitlar.map((k) => ({
    ...k.blocked,
    blockedAt: k.createdAt,
  }));
};