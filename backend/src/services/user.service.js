import * as userRepo from "../repositories/user.repository.js";
import * as blockRepo from "../repositories/block.repository.js";
import * as tokenRepo from "../repositories/refreshToken.repository.js";
import { hashPassword, comparePassword } from "../utils/password.js";
import { ApiError } from "../utils/ApiError.js";
import { kimlikAlanlari } from "../validators/user.validator.js";
import logger from "../utils/logger.js";
import * as fileService from "./file.service.js";

export const getMyProfile = async (userId) => {
  const kullanici = await userRepo.findById(userId);

  if (!kullanici) {
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
  }

  return kullanici;
};

export const updateProfile = async (userId, veriler) => {
  const { currentPassword, ...guncellenecek } = veriler;

  // Kimlik alanlari degisiyorsa once sifre dogrulanir. Boylece acik kalmis bir
  // oturumu ele geciren kisi hesabin giris bilgilerini degistiremiyor.
  const degisenKimlikAlani = kimlikAlanlari.filter(
    (alan) => guncellenecek[alan] !== undefined
  );

  if (degisenKimlikAlani.length > 0) {
    const kullanici = await userRepo.findByIdWithPassword(userId);

    if (!kullanici) {
      throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
    }

    const dogruMu = await comparePassword(currentPassword, kullanici.passwordHash);

    if (!dogruMu) {
      throw ApiError.unauthorized("Şifreniz hatalı", "INVALID_CURRENT_PASSWORD");
    }

    // Degismeyen alanlari sorguya sokmuyoruz, kullanici kendi degeriyle
    // catismasin diye
    const degisenler = {};
    for (const alan of degisenKimlikAlani) {
      if (guncellenecek[alan] !== kullanici[alan]) degisenler[alan] = guncellenecek[alan];
    }

    if (Object.keys(degisenler).length > 0) {
      const sahip = await userRepo.existsByUniqueFields(degisenler);

      if (sahip && sahip.id !== userId) {
        if (degisenler.username && sahip.username === degisenler.username) {
          throw ApiError.conflict("Bu kullanıcı adı zaten kullanılıyor", "USERNAME_TAKEN");
        }
        if (degisenler.email && sahip.email === degisenler.email) {
          throw ApiError.conflict("Bu e-posta adresi zaten kullanılıyor", "EMAIL_TAKEN");
        }
        throw ApiError.conflict("Bu telefon numarası zaten kullanılıyor", "PHONE_TAKEN");
      }
    }
  }

  return userRepo.update(userId, guncellenecek);
};

export const changePassword = async (userId, { currentPassword, newPassword }) => {
  const kullanici = await userRepo.findByIdWithPassword(userId);

  if (!kullanici) {
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
  }

  const dogruMu = await comparePassword(currentPassword, kullanici.passwordHash);

  if (!dogruMu) {
    throw ApiError.unauthorized("Mevcut şifre hatalı", "INVALID_CURRENT_PASSWORD");
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
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
  }

  const profil = await userRepo.findProfileById(hedefId);

  if (!profil) {
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
  }

  return profil;
};

export const blockUser = async (userId, hedefId) => {
  if (userId === hedefId) {
    throw ApiError.badRequest("Kendinizi engelleyemezsiniz", "SELF_BLOCK");
  }

  const hedef = await userRepo.findById(hedefId);

  if (!hedef) {
    throw ApiError.notFound("Kullanıcı bulunamadı", "USER_NOT_FOUND");
  }

  const mevcut = await blockRepo.findByPair(userId, hedefId);

  if (mevcut) {
    throw ApiError.conflict("Bu kullanıcı zaten engellenmiş", "ALREADY_BLOCKED");
  }

  await blockRepo.create(userId, hedefId);
  logger.info(`Kullanici engellendi: ${userId} -> ${hedefId}`);
};

export const unblockUser = async (userId, hedefId) => {
  const mevcut = await blockRepo.findByPair(userId, hedefId);

  if (!mevcut) {
    throw ApiError.notFound("Bu kullanıcı engellenmemiş", "NOT_BLOCKED");
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


export const avatarGuncelle = async (userId, dosya) => {
  const bilgi = await fileService.gorselIsle(dosya.path, { maxGenislik: 512, kalite: 85 });
  const url = fileService.urlUret("avatars", bilgi.dosyaAdi);

  const eskiKullanici = await userRepo.findById(userId);

  const guncel = await userRepo.update(userId, { avatarUrl: url });

  // Eski avatari diskten sil
  if (eskiKullanici?.avatarUrl) {
    await fileService.dosyaSil(eskiKullanici.avatarUrl);
  }

  logger.info(`Avatar guncellendi: userId=${userId}, ${bilgi.width}x${bilgi.height}`);

  return guncel;
};

export const avatarSil = async (userId) => {
  const kullanici = await userRepo.findById(userId);

  if (!kullanici?.avatarUrl) {
    throw ApiError.notFound("Profil fotoğrafı bulunamadı", "NO_AVATAR");
  }

  await fileService.dosyaSil(kullanici.avatarUrl);
  return userRepo.update(userId, { avatarUrl: null });
};