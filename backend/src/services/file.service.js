import sharp from "sharp";
import fs from "fs/promises";
import path from "path";
import { env } from "../config/env.js";
import logger from "../utils/logger.js";

const MIME_TURLERI = {
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".webp": "image/webp",
  ".gif": "image/gif",
};

// Diskteki dosyanin olcu, boyut ve tur bilgisini toplar
const gorselBilgisi = async (yol) => {
  const istatistik = await fs.stat(yol);
  const uzanti = path.extname(yol).toLowerCase();

  let width = null;
  let height = null;

  try {
    const bilgi = await sharp(yol).metadata();
    width = bilgi.width ?? null;
    height = bilgi.height ?? null;
  } catch {
    // Olcu okunamazsa null kalir, mesaj yine de gonderilir
  }

  return {
    width,
    height,
    sizeBytes: istatistik.size,
    dosyaAdi: path.basename(yol),
    mimeType: MIME_TURLERI[uzanti] ?? "application/octet-stream",
  };
};

// Yuklenen gorseli yeniden boyutlandirip sikistirir.
// Cikti her zaman .jpg olarak yazilir; daha once icerik JPEG'e cevriliyor ama
// dosya adi .png kaliyordu ve servis edilen Content-Type yanlis oluyordu.
export const gorselIsle = async (dosyaYolu, { maxGenislik = 1280, kalite = 80 } = {}) => {
  const uzanti = path.extname(dosyaYolu).toLowerCase();

  // GIF donusturulmez, aksi halde animasyon kaybolur
  if (uzanti === ".gif") {
    return gorselBilgisi(dosyaYolu);
  }

  const dizin = path.dirname(dosyaYolu);
  const taban = path.basename(dosyaYolu, path.extname(dosyaYolu));
  const hedefYol = path.join(dizin, `${taban}.jpg`);
  const gecici = `${dosyaYolu}.tmp`;

  try {
    await sharp(dosyaYolu)
      .rotate()
      .resize({ width: maxGenislik, withoutEnlargement: true })
      .jpeg({ quality: kalite })
      .toFile(gecici);

    if (hedefYol !== dosyaYolu) {
      await fs.rm(dosyaYolu, { force: true });
    }

    await fs.rename(gecici, hedefYol);

    return gorselBilgisi(hedefYol);
  } catch (error) {
    logger.error("Gorsel islenemedi", { dosyaYolu, message: error.message });
    await fs.unlink(gecici).catch(() => {});

    // Islenemezse orijinal dosya oldugu gibi kullanilir
    return gorselBilgisi(dosyaYolu);
  }
};

// Dosya yolundan public URL uretir
export const urlUret = (altKlasor, dosyaAdi) =>
  `${env.BASE_URL}/${env.UPLOAD_DIR}/${altKlasor}/${dosyaAdi}`;

// URL'den disk yolunu bulup dosyayi siler
export const dosyaSil = async (url) => {
  if (!url) return;

  try {
    const parcalar = url.split(`/${env.UPLOAD_DIR}/`);
    if (parcalar.length < 2) return;

    const yol = path.join(process.cwd(), env.UPLOAD_DIR, parcalar[1]);
    await fs.unlink(yol);
  } catch (error) {
    // Dosya zaten yoksa sorun degil
    if (error.code !== "ENOENT") {
      logger.warn("Dosya silinemedi", { url, message: error.message });
    }
  }
};