import { Router } from "express";
import * as messageController from "../controllers/message.controller.js";
import { girisKontrol } from "../middlewares/auth.middleware.js";
import { validate } from "../middlewares/validate.js";
import {
  mesajGorseliUpload,
  mesajDosyasiUpload,
  uploadHandler,
} from "../middlewares/upload.js";
import {
  yeniSohbetMesajSchema,
  messageIdSchema,
} from "../validators/conversation.validator.js";

const router = Router();

router.use(girisKontrol);

// Yeni sohbet baslatip ilk mesaji gonderir
router.post("/", validate(yeniSohbetMesajSchema), messageController.yeniSohbetBaslat);

// Ilk mesaj gorsel veya dosya oldugunda kullanilir. Alici id'si multipart govdede
// geldigi icin dogrulama, dosya diske yazildiktan sonra serviste yapiliyor.
router.post("/image", uploadHandler(mesajGorseliUpload), messageController.yeniSohbetGorsel);
router.post("/file", uploadHandler(mesajDosyasiUpload), messageController.yeniSohbetDosya);

// Mesaj silme - sadece kendi mesajini
router.delete("/:id", validate(messageIdSchema), messageController.sil);

export default router;