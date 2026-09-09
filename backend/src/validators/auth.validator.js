import { z } from 'zod';

const passwordSchema = z
  .string()
  .min(8, 'Sifre en az 8 karakter olmali')
  .max(72, 'Sifre en fazla 72 karakter olabilir')
  .regex(/[a-z]/, 'Sifre en az bir kucuk harf icermeli')
  .regex(/[A-Z]/, 'Sifre en az bir buyuk harf icermeli')
  .regex(/[0-9]/, 'Sifre en az bir rakam icermeli');

export const registerSchema = z.object({
  body: z.object({
    username: z
      .string()
      .min(3, 'Kullanici adi en az 3 karakter olmali')
      .max(30, 'Kullanici adi en fazla 30 karakter olabilir')
      .regex(/^[a-z0-9_]+$/, 'Kullanici adi sadece kucuk harf, rakam ve alt cizgi icerebilir'),
    email: z.string().email('Gecerli bir e-posta adresi girin').toLowerCase(),
    phone: z
      .string()
      .regex(/^\+90[0-9]{10}$/, 'Telefon numarasi +905XXXXXXXXX formatinda olmali'),
    fullName: z
      .string()
      .min(2, 'Ad soyad en az 2 karakter olmali')
      .max(100, 'Ad soyad en fazla 100 karakter olabilir')
      .trim(),
    password: passwordSchema,
  }),
});

export const loginSchema = z.object({
  body: z.object({
    identifier: z.string().min(1, 'Kullanici adi, e-posta veya telefon gerekli'),
    password: z.string().min(1, 'Sifre gerekli'),
  }),
});

export const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1, 'Refresh token gerekli'),
  }),
});

export const logoutSchema = z.object({
  body: z.object({
    refreshToken: z.string().optional(),
  }),
});