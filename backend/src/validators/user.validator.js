import { z } from "zod";

export const updateProfileSchema = z.object({
  body: z
    .object({
      fullName: z
        .string()
        .min(2, "Ad soyad en az 2 karakter olmali")
        .max(100, "Ad soyad en fazla 100 karakter olabilir")
        .trim()
        .optional(),
      username: z
        .string()
        .min(3, "Kullanici adi en az 3 karakter olmali")
        .max(30, "Kullanici adi en fazla 30 karakter olabilir")
        .regex(/^[a-z0-9_]+$/, "Kullanici adi sadece kucuk harf, rakam ve alt cizgi icerebilir")
        .optional(),
      bio: z.string().max(160, "Bio en fazla 160 karakter olabilir").trim().nullable().optional(),
      notificationsEnabled: z.boolean().optional(),
      notificationPreview: z.enum(["NAME_AND_MESSAGE", "NAME_ONLY", "NONE"]).optional(),
    })
    .refine((data) => Object.keys(data).length > 0, {
      message: "Guncellenecek en az bir alan gonderilmeli",
    }),
});

export const changePasswordSchema = z.object({
  body: z.object({
    currentPassword: z.string().min(1, "Mevcut sifre gerekli"),
    newPassword: z
      .string()
      .min(8, "Yeni sifre en az 8 karakter olmali")
      .max(72, "Yeni sifre en fazla 72 karakter olabilir")
      .regex(/[a-z]/, "Yeni sifre en az bir kucuk harf icermeli")
      .regex(/[A-Z]/, "Yeni sifre en az bir buyuk harf icermeli")
      .regex(/[0-9]/, "Yeni sifre en az bir rakam icermeli"),
  }),
});

export const searchSchema = z.object({
  query: z.object({
    q: z.string().min(2, "Arama terimi en az 2 karakter olmali").trim(),
    limit: z.coerce.number().min(1).max(50).default(20).optional(),
  }),
});

export const userIdSchema = z.object({
  params: z.object({
    id: z.string().uuid("Gecersiz kullanici id"),
  }),
});