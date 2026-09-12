import http from "http";
import app from "./app.js";
import { env } from "./config/env.js";
import prisma from "./config/database.js";
import logger from "./utils/logger.js";
import { initSocket } from "./config/socket.js";
import { initFirebase } from "./config/firebase.js";

const httpServer = http.createServer(app);

initSocket(httpServer);

const server = httpServer.listen(env.PORT, () => {
  logger.info(`Sunucu ${env.PORT} portunda calisiyor (${env.NODE_ENV})`);
});

const shutdown = async (signal) => {
  logger.info(`${signal} alindi, sunucu kapatiliyor...`);
  server.close(async () => {
    await prisma.$disconnect();
    logger.info("Baglantilar kapatildi.");
    process.exit(0);
  });
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
initFirebase();
initSocket(httpServer);

process.on("unhandledRejection", (reason) => {
  logger.error("Yakalanmamis promise reddi", { reason });
});

process.on("uncaughtException", (err) => {
  logger.error("Yakalanmamis istisna", { message: err.message, stack: err.stack });
  process.exit(1);
});