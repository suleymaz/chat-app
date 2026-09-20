import { Router } from "express";
import * as conversationController from "../controllers/conversation.controller.js";
import * as messageController from "../controllers/message.controller.js";
import { girisKontrol } from "../middlewares/auth.middleware.js";
import { validate } from "../middlewares/validate.js";
import { mesajGorseliUpload, uploadHandler, mesajDosyasiUpload } from "../middlewares/upload.js";
import {
  sohbetBaslatSchema,
  conversationIdSchema,
  mesajListeSchema,
  mesajGonderSchema,
  mesajAraSchema,
  arsivSchema,
  sessizSchema,
} from "../validators/conversation.validator.js";

const router = Router();

router.use(girisKontrol);

// Sohbet listesi - ?archived=true ile arsivlenmisler
router.get("/", conversationController.listele);

// Bir kullaniciyla olan sohbeti bul, yoksa isNew: true doner
router.post("/with-user", validate(sohbetBaslatSchema), conversationController.kullaniciylaSohbet);

// Sohbet detayi ve islemleri
router.get("/:id", validate(conversationIdSchema), conversationController.detay);
router.delete("/:id", validate(conversationIdSchema), conversationController.sil);
router.post("/:id/read", validate(conversationIdSchema), conversationController.okunduIsaretle);
router.patch("/:id/archive", validate(arsivSchema), conversationController.arsivle);
router.patch("/:id/mute", validate(sessizSchema), conversationController.sessizeAl);

// Sohbet icindeki mesajlar
router.get("/:id/messages", validate(mesajListeSchema), messageController.listele);
router.post("/:id/messages", validate(mesajGonderSchema), messageController.gonder);
// Ek yuklerken once sohbet id'si dogrulanir - gecersiz id icin dosya diske yazilmasin
router.post(
  "/:id/messages/image",
  validate(conversationIdSchema),
  uploadHandler(mesajGorseliUpload),
  messageController.gorselGonder
);
router.post(
  "/:id/messages/file",
  validate(conversationIdSchema),
  uploadHandler(mesajDosyasiUpload),
  messageController.dosyaGonder
);
router.get("/:id/messages/search", validate(mesajAraSchema), messageController.ara);

export default router;