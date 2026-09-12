import { z } from "zod";

export const cihazKaydetSchema = z.object({
  body: z.object({
    fcmToken: z.string().min(1, "FCM token gerekli"),
    platform: z.enum(["android", "ios", "web"]),
  }),
});

export const cihazSilSchema = z.object({
  body: z.object({
    fcmToken: z.string().min(1, "FCM token gerekli"),
  }),
});