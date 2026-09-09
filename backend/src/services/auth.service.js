import * as userRepo from '../repositories/user.repository.js';
import * as tokenRepo from '../repositories/refreshToken.repository.js';
import { hashPassword, comparePassword } from '../utils/password.js';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  hashToken,
  getExpiryDate,
} from '../utils/token.js';
import { ApiError } from '../utils/ApiError.js';
import logger from '../utils/logger.js';

const issueTokens = async (userId) => {
  const accessToken = signAccessToken(userId);
  const refreshToken = signRefreshToken(userId);

  await tokenRepo.create({
    userId,
    tokenHash: hashToken(refreshToken),
    expiresAt: getExpiryDate(refreshToken),
  });

  return { accessToken, refreshToken };
};

export const register = async ({ username, email, phone, password, fullName }) => {
  const existing = await userRepo.existsByUniqueFields({ username, email, phone });

  if (existing) {
    if (existing.username === username) {
      throw ApiError.conflict('Bu kullanici adi zaten kullaniliyor', 'USERNAME_TAKEN');
    }
    if (existing.email === email) {
      throw ApiError.conflict('Bu e-posta adresi zaten kayitli', 'EMAIL_TAKEN');
    }
    throw ApiError.conflict('Bu telefon numarasi zaten kayitli', 'PHONE_TAKEN');
  }

  const passwordHash = await hashPassword(password);

  const user = await userRepo.create({
    username,
    email,
    phone,
    fullName,
    passwordHash,
  });

  const tokens = await issueTokens(user.id);

  logger.info(`Yeni kullanici kaydi: ${user.username}`);

  return { user, ...tokens };
};

export const login = async ({ identifier, password }) => {
  const user = await userRepo.findByLoginIdentifier(identifier);

  if (!user) {
    throw ApiError.unauthorized('Kullanici adi veya sifre hatali', 'INVALID_CREDENTIALS');
  }

  const isValid = await comparePassword(password, user.passwordHash);

  if (!isValid) {
    throw ApiError.unauthorized('Kullanici adi veya sifre hatali', 'INVALID_CREDENTIALS');
  }

  const tokens = await issueTokens(user.id);
  const { passwordHash, ...safeUser } = user;

  return { user: safeUser, ...tokens };
};

export const refresh = async (refreshToken) => {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw ApiError.unauthorized('Gecersiz veya suresi dolmus token', 'INVALID_REFRESH_TOKEN');
  }

  const stored = await tokenRepo.findByHash(hashToken(refreshToken));

  if (!stored) {
    throw ApiError.unauthorized('Gecersiz token', 'INVALID_REFRESH_TOKEN');
  }

  if (stored.revokedAt) {
    logger.warn(`Iptal edilmis refresh token kullanildi. userId=${stored.userId}`);
    await tokenRepo.revokeAllForUser(stored.userId);
    throw ApiError.unauthorized('Oturum guvenligi nedeniyle sonlandirildi', 'TOKEN_REUSE_DETECTED');
  }

  if (stored.expiresAt < new Date()) {
    throw ApiError.unauthorized('Token suresi dolmus', 'REFRESH_TOKEN_EXPIRED');
  }

  await tokenRepo.revokeById(stored.id);

  const tokens = await issueTokens(payload.sub);
  const user = await userRepo.findById(payload.sub);

  return { user, ...tokens };
};

export const logout = async (refreshToken) => {
  if (!refreshToken) return;

  const stored = await tokenRepo.findByHash(hashToken(refreshToken));

  if (stored && !stored.revokedAt) {
    await tokenRepo.revokeById(stored.id);
  }
};

export const logoutAll = async (userId) => {
  await tokenRepo.revokeAllForUser(userId);
};