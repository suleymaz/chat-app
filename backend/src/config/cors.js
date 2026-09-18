import { env } from "./env.js";

// CORS_ORIGIN "*" ise herkese acik, degilse virgulle ayrilmis liste olarak okunur.
// Hem HTTP hem Socket.IO ayni kaynagi kullanir.
export const corsOrigin = () => {
  if (env.CORS_ORIGIN.trim() === "*") return "*";

  return env.CORS_ORIGIN.split(",")
    .map((kaynak) => kaynak.trim())
    .filter(Boolean);
};
