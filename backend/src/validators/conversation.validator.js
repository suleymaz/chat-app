import { z } from "zod";

export const sohbetBaslatSchema = z.object({
  body: z.object({
    userId: z.string().uuid("Gecersiz kullanici id"),
  }),
});

export const conversationIdSchema = z.object({
  params: z.object({
    id: z.string().uuid("Gecersiz sohbet id"),
  }),
});

export const mesajListeSchema = z.object({
  params: z.object({
    id: z.string().uuid("Gecersiz sohbet id"),
  }),
  query: z.object({
    cursor: z.string().datetime().optional(),
    limit: z.coerce.number().min(1).max(100).default(30).optional(),
  }),
});

export const mesajGonderSchema = z.object({
  params: z.object({
    id: z.string().uuid("Gecersiz sohbet id"),
  }),
  body: z.object({
    content: z
      .string()
      .min(1, "Mesaj bos olamaz")
      .max(4000, "Mesaj en fazla 4000 karakter olabilir")
      .trim(),
  }),
});

export const yeniSohbetMesajSchema = z.object({
  body: z.object({
    userId: z.string().uuid("Gecersiz kullanici id"),
    content: z
      .string()
      .min(1, "Mesaj bos olamaz")
      .max(4000, "Mesaj en fazla 4000 karakter olabilir")
      .trim(),
  }),
});

export const messageIdSchema = z.object({
  params: z.object({
    id: z.string().uuid("Gecersiz mesaj id"),
  }),
});

export const mesajAraSchema = z.object({
  params: z.object({
    id: z.string().uuid("Gecersiz sohbet id"),
  }),
  query: z.object({
    q: z.string().min(2, "Arama terimi en az 2 karakter olmali").trim(),
    limit: z.coerce.number().min(1).max(50).default(20).optional(),
  }),
});

export const arsivSchema = z.object({
  params: z.object({
    id: z.string().uuid("Gecersiz sohbet id"),
  }),
  body: z.object({
    archived: z.boolean(),
  }),
});