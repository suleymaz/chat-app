import http from "http";
import app from "./app.js";
import { env } from "./config/env.js";
import prisma from "./config/database.js";
import logger from "./utils/logger.js";
import { initSocket } from "./config/socket.js";
import { initFirebase } from "./config/firebase.js";
import * as tokenRepo from "./repositories/refreshToken.repository.js";

const httpServer = http.createServer(app);

initFirebase();
initSocket(httpServer);

const server = httpServer.listen(env.PORT, () => {
  logger.info(`Sunucu ${env.PORT} portunda calisiyor (${env.NODE_ENV})`);
});

// Suresi dolmus refresh token'lar hicbir zaman silinmiyordu, tablo surekli buyuyordu
const TEMIZLIK_ARALIGI = 24 * 60 * 60 * 1000;

const tokenTemizligi = async () => {
  try {
    const sonuc = await tokenRepo.deleteExpired();

    if (sonuc.count > 0) {
      logger.info(`${sonuc.count} suresi dolmus refresh token silindi`);
    }
  } catch (error) {
    logger.error("Refresh token temizligi basarisiz", { message: error.message });
  }
};

const temizlikZamanlayici = setInterval(tokenTemizligi, TEMIZLIK_ARALIGI);
temizlikZamanlayici.unref();
tokenTemizligi();

const shutdown = async (signal) => {
  logger.info(`${signal} alindi, sunucu kapatiliyor...`);
  clearInterval(temizlikZamanlayici);
  server.close(async () => {
    await prisma.$disconnect();
    logger.info("Baglantilar kapatildi.");
    process.exit(0);
  });
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

process.on("unhandledRejection", (reason) => {
  logger.error("Yakalanmamis promise reddi", { reason });
});

process.on("uncaughtException", (err) => {
  logger.error("Yakalanmamis istisna", { message: err.message, stack: err.stack });
  process.exit(1);
});