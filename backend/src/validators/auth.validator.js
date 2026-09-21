import { z } from 'zod';
import { telefonNormalize, telefonGecerliMi } from '../utils/telefon.js';

const passwordSchema = z
  .string()
  .min(8, 'Şifre en az 8 karakter olmalı')
  .max(72, 'Şifre en fazla 72 karakter olabilir')
  .regex(/[a-z]/, 'Şifre en az bir küçük harf içermeli')
  .regex(/[A-Z]/, 'Şifre en az bir büyük harf içermeli')
  .regex(/[0-9]/, 'Şifre en az bir rakam içermeli');

export const registerSchema = z.object({
  body: z.object({
    username: z
      .string()
      .min(3, 'Kullanıcı adı en az 3 karakter olmalı')
      .max(30, 'Kullanıcı adı en fazla 30 karakter olabilir')
      .regex(/^[a-z0-9_]+$/, 'Kullanıcı adı sadece küçük harf, rakam ve alt çizgi içerebilir'),
    email: z.string().email('Geçerli bir e-posta adresi girin').toLowerCase(),
    phone: z
      .string()
      .transform(telefonNormalize)
      .refine(telefonGecerliMi, 'Telefon numarası 05XXXXXXXXX biçiminde olmalı'),
    fullName: z
      .string()
      .trim()
      .min(2, 'Ad soyad en az 2 karakter olmalı')
      .max(100, 'Ad soyad en fazla 100 karakter olabilir'),
    password: passwordSchema,
  }),
});

export const loginSchema = z.object({
  body: z.object({
    identifier: z.string().min(1, 'Kullanıcı adı, e-posta veya telefon gerekli'),
    password: z.string().min(1, 'Şifre gerekli'),
  }),
});

export const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1, 'Oturum yenileme bilgisi gerekli'),
  }),
});

export const logoutSchema = z.object({
  body: z.object({
    refreshToken: z.string().optional(),
  }),
});