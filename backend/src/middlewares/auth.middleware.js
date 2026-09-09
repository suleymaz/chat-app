import * as userRepo from "../repositories/user.repository.js";
import { verifyAccessToken } from "../utils/token.js";
import { ApiError } from "../utils/ApiError.js";
import { asyncHandler } from "../utils/asyncHandler.js";

// Authorization basligindan Bearer token'i ayiklar
const tokenAyikla = (req) => {
  const header = req.headers.authorization;

  if (!header || !header.startsWith("Bearer ")) {
    return null;
  }

  return header.slice(7).trim();
};

// Giris kontrolu: gecerli access token yoksa istegi reddeder
export const girisKontrol = asyncHandler(async (req, res, next) => {
  const token = tokenAyikla(req);

  if (!token) {
    throw ApiError.unauthorized("Giris yapmaniz gerekiyor", "NO_TOKEN");
  }

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      throw ApiError.unauthorized("Oturum suresi doldu", "TOKEN_EXPIRED");
    }
    throw ApiError.unauthorized("Gecersiz token", "INVALID_TOKEN");
  }

  const kullanici = await userRepo.findById(payload.sub);

  if (!kullanici) {
    throw ApiError.unauthorized("Kullanici bulunamadi", "USER_NOT_FOUND");
  }

  req.user = kullanici;
  next();
});

// Opsiyonel giris: token varsa kullaniciyi ekler, yoksa istegi engellemez
export const opsiyonelGiris = asyncHandler(async (req, res, next) => {
  const token = tokenAyikla(req);

  if (!token) {
    return next();
  }

  try {
    const payload = verifyAccessToken(token);
    req.user = await userRepo.findById(payload.sub);
  } catch {
    // Token gecersizse kullanici eklenmez, istek devam eder
  }

  next();
});