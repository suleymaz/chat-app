import { Router } from "express";
import authRoutes from "./auth.routes.js";
import { girisKontrol } from "../middlewares/auth.middleware.js";

const router = Router();

router.use("/auth", authRoutes);

// Gecici test endpoint'i - Gun 4'te /users/me ile degistirilecek
router.get("/me", girisKontrol, (req, res) => {
  res.json({ success: true, data: req.user });
});

export default router;