import multer from "multer";
import path from "path";
import fs from "fs";
import crypto from "crypto";
import { env } from "../config/env.js";
import { ApiError } from "../utils/ApiError.js";

const GORSEL_TIPLERI  = ["image/jpeg", "image/png", "image/webp", "image/gif"];

const DOSYA_TIPLERI = [
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "text/plain",
  "text/csv",
  "application/zip",
  "application/x-zip-compressed",
  "application/x-rar-compressed",
];




// Klasorleri baslangicta olustur
const klasorHazirla = (altKlasor) => {
  const yol = path.join(process.cwd(), env.UPLOAD_DIR, altKlasor);

  if (!fs.existsSync(yol)) {
    fs.mkdirSync(yol, { recursive: true });
  }

  return yol;
};

klasorHazirla("avatars");
klasorHazirla("messages");
klasorHazirla("files");

const storage = (altKlasor) =>
  multer.diskStorage({
    destination: (req, file, cb) => {
      cb(null, klasorHazirla(altKlasor));
    },
    filename: (req, file, cb) => {
      // Orijinal dosya adi kullanilmiyor - path traversal ve cakisma riski
      const uzanti = path.extname(file.originalname).toLowerCase();
      const ad = `${Date.now()}-${crypto.randomBytes(8).toString("hex")}${uzanti}`;
      cb(null, ad);
    },
  });

const gorselFiltre = (req, file, cb) => {
  if (!GORSEL_TIPLERI.includes(file.mimetype)) {
    return cb(ApiError.badRequest("Sadece JPEG, PNG, WEBP ve GIF yuklenebilir", "INVALID_FILE_TYPE"));
  }
  cb(null, true);
};

const dosyaFiltre = (req, file, cb) => {
  const izinli = [...GORSEL_TIPLERI, ...DOSYA_TIPLERI];

  if (!izinli.includes(file.mimetype)) {
    return cb(ApiError.badRequest("Bu dosya turu desteklenmiyor", "INVALID_FILE_TYPE"));
  }
  cb(null, true);
};

export const avatarUpload = multer({
  storage: storage("avatars"),
  fileFilter: gorselFiltre,
  limits: { fileSize: env.MAX_FILE_SIZE },
}).single("file");

export const mesajGorseliUpload = multer({
  storage: storage("messages"),
  fileFilter: gorselFiltre,
  limits: { fileSize: env.MAX_FILE_SIZE },
}).single("file");

export const mesajDosyasiUpload = multer({
  storage: storage("files"),
  fileFilter: dosyaFiltre,
  limits: { fileSize: env.MAX_DOCUMENT_SIZE },
}).single("file");

// Multer hatalarini ApiError'a cevirir
export const uploadHandler = (uploader) => (req, res, next) => {
  uploader(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      if (err.code === "LIMIT_FILE_SIZE") {
        const mb = Math.round(env.MAX_FILE_SIZE / 1024 / 1024);
        return next(ApiError.badRequest(`Dosya boyutu en fazla ${mb} MB olabilir`, "FILE_TOO_LARGE"));
      }
      return next(ApiError.badRequest("Dosya yuklenemedi", "UPLOAD_ERROR"));
    }

    if (err) return next(err);

    if (!req.file) {
      return next(ApiError.badRequest("Dosya gonderilmedi", "NO_FILE"));
    }

    next();
  });
};