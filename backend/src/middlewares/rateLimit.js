import rateLimit from 'express-rate-limit';
import { ApiError } from '../utils/ApiError.js';

import { env } from '../config/env.js';

const handler = (req, res, next) => {
  next(ApiError.tooManyRequests());
};

// Otomatik testler tek IP'den yuzlerce istek atiyor ve auth limitine ilk
// dakikada takiliyor. Sinir yalnizca test ortaminda devre disi birakiliyor.
const skip = () => env.NODE_ENV === 'test';

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  handler,
  skip,
  skipSuccessfulRequests: true,
});

export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  handler,
  skip,
});