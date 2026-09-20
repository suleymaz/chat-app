// firebase-admin 13'ten itibaren ESM tarafinda eski "admin.credential" /
// "admin.messaging()" ad alani yok; modul bazli API kullaniliyor.
import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import fs from "fs";
import path from "path";
import { env } from "./env.js";
import logger from "../utils/logger.js";

let firebaseHazir = false;

export const initFirebase = () => {
  const anahtarYolu = env.FIREBASE_SERVICE_ACCOUNT_PATH;

  if (!anahtarYolu) {
    logger.warn("Firebase yapilandirilmamis - bildirimler devre disi");
    return;
  }

  const tamYol = path.isAbsolute(anahtarYolu)
    ? anahtarYolu
    : path.join(process.cwd(), anahtarYolu);

  if (!fs.existsSync(tamYol)) {
    logger.warn(`Firebase anahtar dosyasi bulunamadi: ${tamYol} - bildirimler devre disi`);
    return;
  }

  try {
    const serviceAccount = JSON.parse(fs.readFileSync(tamYol, "utf8"));

    // Nodemon yeniden baslattiginda ayni uygulamayi ikinci kez kurmayalim
    if (getApps().length === 0) {
      initializeApp({ credential: cert(serviceAccount) });
    }

    firebaseHazir = true;
    logger.info("Firebase baslatildi");
  } catch (error) {
    logger.error("Firebase baslatilamadi", { message: error.message });
  }
};

export const firebaseKullanilabilir = () => firebaseHazir;

// Bildirim gonderiminde kullanilir - Firebase hazir degilse cagrilmamali
export const mesajlasma = () => getMessaging();
