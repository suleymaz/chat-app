import sharp from "sharp";
import fs from "fs/promises";
import path from "path";
import { env } from "../config/env.js";
import logger from "../utils/logger.js";

// Yuklenen gorseli yeniden boyutlandirip sikistirir
export const gorselIsle = async (dosyaYolu, { maxGenislik = 1280, kalite = 80 } = {}) => {
  const gecici = `${dosyaYolu}.tmp`;

  try {
    const bilgi = await sharp(dosyaYolu).metadata();

    await sharp(dosyaYolu)
      .rotate()
      .resize({ width: maxGenislik, withoutEnlargement: true })
      .jpeg({ quality: kalite })
      .toFile(gecici);

    await fs.rename(gecici, dosyaYolu);

    const yeniBilgi = await sharp(dosyaYolu).metadata();
    const istatistik = await fs.stat(dosyaYolu);

    return {
      width: yeniBilgi.width,
      height: yeniBilgi.height,
      sizeBytes: istatistik.size,
      orijinalBoyut: { width: bilgi.width, height: bilgi.height },
    };
  } catch (error) {
    logger.error("Gorsel islenemedi", { dosyaYolu, message: error.message });
    await fs.unlink(gecici).catch(() => {});

    const istatistik = await fs.stat(dosyaYolu);
    return { width: null, height: null, sizeBytes: istatistik.size };
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