import { Router } from "express";
import * as messageController from "../controllers/message.controller.js";
import { girisKontrol } from "../middlewares/auth.middleware.js";
import { validate } from "../middlewares/validate.js";
import {
  yeniSohbetMesajSchema,
  messageIdSchema,
} from "../validators/conversation.validator.js";

const router = Router();

router.use(girisKontrol);

// Yeni sohbet baslatip ilk mesaji gonderir
router.post("/", validate(yeniSohbetMesajSchema), messageController.yeniSohbetBaslat);

// Mesaj silme - sadece kendi mesajini
router.delete("/:id", validate(messageIdSchema), messageController.sil);

export default router;