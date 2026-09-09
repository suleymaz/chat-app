import { Router } from "express";
import * as authController from "../controllers/auth.controller.js";
import { validate } from "../middlewares/validate.js";
import { authLimiter } from "../middlewares/rateLimit.js";
import {
  registerSchema,
  loginSchema,
  refreshSchema,
  logoutSchema,
} from "../validators/auth.validator.js";

const router = Router();

// Kayit: giris gerektirmez, brute-force korumasi icin rate limit uygulanir
router.post("/register", authLimiter, validate(registerSchema), authController.register);

// Giris: kullanici adi, e-posta veya telefon ile yapilabilir
router.post("/login", authLimiter, validate(loginSchema), authController.login);

// Token yenileme: refresh token ile yeni access token alinir
router.post("/refresh", validate(refreshSchema), authController.refresh);

// Cikis: refresh token iptal edilir
router.post("/logout", validate(logoutSchema), authController.logout);

export default router;