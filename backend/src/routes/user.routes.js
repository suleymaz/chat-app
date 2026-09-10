import { Router } from "express";
import * as userController from "../controllers/user.controller.js";
import { girisKontrol } from "../middlewares/auth.middleware.js";
import { validate } from "../middlewares/validate.js";
import {
  updateProfileSchema,
  changePasswordSchema,
  searchSchema,
  userIdSchema,
} from "../validators/user.validator.js";

const router = Router();

// Tum kullanici endpoint'leri giris gerektirir
router.use(girisKontrol);

// Kendi profil islemleri
router.get("/me", userController.getMe);
router.patch("/me", validate(updateProfileSchema), userController.updateMe);
router.patch("/me/password", validate(changePasswordSchema), userController.changePassword);

// Engellenen kullanicilar - /:id'den once tanimlanmali
router.get("/me/blocked", userController.getBlockedUsers);

// Kullanici arama
router.get("/search", validate(searchSchema), userController.searchUsers);

// Diger kullanicilar
router.get("/:id", validate(userIdSchema), userController.getUserById);
router.post("/:id/block", validate(userIdSchema), userController.blockUser);
router.delete("/:id/block", validate(userIdSchema), userController.unblockUser);

export default router;