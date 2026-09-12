import { Router } from "express";
import * as notificationController from "../controllers/notification.controller.js";
import { girisKontrol } from "../middlewares/auth.middleware.js";
import { validate } from "../middlewares/validate.js";
import { cihazKaydetSchema, cihazSilSchema } from "../validators/notification.validator.js";

const router = Router();

router.use(girisKontrol);

// Cihaz FCM token kaydi
router.post("/token", validate(cihazKaydetSchema), notificationController.cihazKaydet);
router.delete("/token", validate(cihazSilSchema), notificationController.cihazSil);

export default router;