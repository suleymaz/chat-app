import { z } from "zod";
import { telefonNormalize, telefonGecerliMi } from "../utils/telefon.js";

// Hesabin kimligini belirleyen alanlar. Degistirilmeleri icin mevcut sifre
// isteniyor: telefonu birine odunc veren kullanicinin hesabi, acik oturum
// uzerinden kullanici adi ve e-posta degistirilerek ele gecirilebilirdi.
export const kimlikAlanlari = ["username", "email", "phone"];

export const updateProfileSchema = z.object({
  body: z
    .object({
      fullName: z
        .string()
        .trim()
        .min(2, "Ad soyad en az 2 karakter olmalı")
        .max(100, "Ad soyad en fazla 100 karakter olabilir")
        .optional(),
      username: z
        .string()
        .trim()
        .min(3, "Kullanıcı adı en az 3 karakter olmalı")
        .max(30, "Kullanıcı adı en fazla 30 karakter olabilir")
        .regex(/^[a-z0-9_]+$/, "Kullanıcı adı sadece küçük harf, rakam ve alt çizgi içerebilir")
        .optional(),
      email: z
        .string()
        .trim()
        .email("Geçerli bir e-posta adresi girin")
        .toLowerCase()
        .optional(),
      phone: z
        .string()
        .trim()
        .transform(telefonNormalize)
        .refine(telefonGecerliMi, "Telefon numarası 05XXXXXXXXX biçiminde olmalı")
        .optional(),
      bio: z.string().trim().max(160, "Hakkımda en fazla 160 karakter olabilir").nullable().optional(),
      notificationsEnabled: z.boolean().optional(),
      notificationPreview: z.enum(["NAME_AND_MESSAGE", "NAME_ONLY", "NONE"]).optional(),
      currentPassword: z.string().min(1, "Mevcut şifre gerekli").optional(),
    })
    .refine((data) => Object.keys(data).length > 0, {
      message: "Güncellenecek en az bir alan gönderilmeli",
    })
    .refine(
      (data) => !kimlikAlanlari.some((alan) => data[alan] !== undefined) || !!data.currentPassword,
      {
        message: "Bu değişiklik için mevcut şifrenizi girmelisiniz",
        path: ["currentPassword"],
      }
    ),
});

export const changePasswordSchema = z.object({
  body: z.object({
    currentPassword: z.string().min(1, "Mevcut şifre gerekli"),
    newPassword: z
      .string()
      .min(8, "Yeni şifre en az 8 karakter olmalı")
      .max(72, "Yeni şifre en fazla 72 karakter olabilir")
      .regex(/[a-z]/, "Yeni şifre en az bir küçük harf içermeli")
      .regex(/[A-Z]/, "Yeni şifre en az bir büyük harf içermeli")
      .regex(/[0-9]/, "Yeni şifre en az bir rakam içermeli"),
  }),
});

export const searchSchema = z.object({
  query: z.object({
    q: z.string().trim().min(2, "Arama terimi en az 2 karakter olmalı"),
    limit: z.coerce.number().min(1).max(50).default(20).optional(),
  }),
});

export const userIdSchema = z.object({
  params: z.object({
    id: z.string().uuid("Geçersiz kullanıcı kimliği"),
  }),
});