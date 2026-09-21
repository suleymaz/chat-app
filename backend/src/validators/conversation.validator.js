import { z } from "zod";

export const sohbetBaslatSchema = z.object({
  body: z.object({
    userId: z.string().uuid("Geçersiz kullanıcı kimliği"),
  }),
});

export const conversationIdSchema = z.object({
  params: z.object({
    id: z.string().uuid("Geçersiz sohbet kimliği"),
  }),
});

export const mesajListeSchema = z.object({
  params: z.object({
    id: z.string().uuid("Geçersiz sohbet kimliği"),
  }),
  query: z.object({
    // Imlec "ISO tarih|mesaj id" bicimindedir, istemci icin opak bir degerdir
    cursor: z.string().max(120).optional(),
    limit: z.coerce.number().min(1).max(100).default(30).optional(),
  }),
});

export const mesajGonderSchema = z.object({
  params: z.object({
    id: z.string().uuid("Geçersiz sohbet kimliği"),
  }),
  body: z.object({
    content: z
      .string()
      .trim()
      .min(1, "Mesaj boş olamaz")
      .max(4000, "Mesaj en fazla 4000 karakter olabilir"),
  }),
});

export const yeniSohbetMesajSchema = z.object({
  body: z.object({
    userId: z.string().uuid("Geçersiz kullanıcı kimliği"),
    content: z
      .string()
      .trim()
      .min(1, "Mesaj boş olamaz")
      .max(4000, "Mesaj en fazla 4000 karakter olabilir"),
  }),
});

export const messageIdSchema = z.object({
  params: z.object({
    id: z.string().uuid("Geçersiz mesaj kimliği"),
  }),
});

export const mesajAraSchema = z.object({
  params: z.object({
    id: z.string().uuid("Geçersiz sohbet kimliği"),
  }),
  query: z.object({
    q: z.string().trim().min(2, "Arama terimi en az 2 karakter olmalı"),
    limit: z.coerce.number().min(1).max(50).default(20).optional(),
  }),
});

export const arsivSchema = z.object({
  params: z.object({
    id: z.string().uuid("Geçersiz sohbet kimliği"),
  }),
  body: z.object({
    archived: z.boolean(),
  }),
});

export const sessizSchema = z.object({
  params: z.object({
    id: z.string().uuid("Geçersiz sohbet kimliği"),
  }),
  body: z.object({
    muted: z.boolean(),
  }),
});