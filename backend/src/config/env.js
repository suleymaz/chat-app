import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(5000),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),

  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET en az 32 karakter olmali'),
  JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET en az 32 karakter olmali'),
  JWT_ACCESS_EXPIRES_IN: z.string().default('15m'),
  JWT_REFRESH_EXPIRES_IN: z.string().default('7d'),
  BCRYPT_SALT_ROUNDS: z.coerce.number().default(10),

  UPLOAD_DIR: z.string().default("uploads"),
  MAX_FILE_SIZE: z.coerce.number().default(5 * 1024 * 1024),
  MAX_DOCUMENT_SIZE: z.coerce.number().default(20 * 1024 * 1024),
  FIREBASE_SERVICE_ACCOUNT_PATH: z.string().optional(),

  // Virgulle ayrilmis origin listesi. Uretimde daraltilmali, gelistirmede "*"
  CORS_ORIGIN: z.string().default("*"),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment variables:');
  console.error(z.treeifyError(parsed.error));
  process.exit(1);
}

export const env = parsed.data;