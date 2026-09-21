import { Prisma } from '@prisma/client';
import { ApiError } from '../utils/ApiError.js';
import { env } from '../config/env.js';
import logger from '../utils/logger.js';

export const notFoundHandler = (req, res, next) => {
  next(ApiError.notFound(`Endpoint bulunamadi: ${req.method} ${req.originalUrl}`));
};

export const errorHandler = (err, req, res, next) => {
  let error = err;

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    error = mapPrismaError(error);
  }

  // body-parser bozuk veya cok buyuk govdede hata firlatiyor. Bunlar istemci
  // hatasi; yakalanmazsa 500 donup gelistirme kipinde yigin izi de sizdiriyordu.
  if (error?.type === 'entity.parse.failed') {
    error = ApiError.badRequest('Gonderilen JSON okunamadi', 'INVALID_JSON');
  } else if (error?.type === 'entity.too.large') {
    error = ApiError.badRequest('Gonderilen veri cok buyuk', 'PAYLOAD_TOO_LARGE');
  }

  if (!(error instanceof ApiError)) {
    logger.error('Beklenmeyen hata', { message: err.message, stack: err.stack });
    error = ApiError.internal();
  } else if (error.statusCode >= 500) {
    logger.error(error.message, { stack: err.stack });
  } else {
    logger.warn(`${error.statusCode} ${error.code}: ${error.message}`);
  }

  const body = {
    success: false,
    error: {
      code: error.code || 'ERROR',
      message: error.message,
    },
  };

  if (error.details) {
    body.error.details = error.details;
  }

  if (env.NODE_ENV === 'development' && error.statusCode >= 500) {
    body.error.stack = err.stack;
  }

  res.status(error.statusCode || 500).json(body);
};

function mapPrismaError(err) {
  switch (err.code) {
    case 'P2002': {
      const field = err.meta?.target?.[0] ?? 'alan';
      return ApiError.conflict(`Bu ${field} zaten kullaniliyor`, 'DUPLICATE_FIELD');
    }
    case 'P2025':
      return ApiError.notFound('Kayıt bulunamadı', 'NOT_FOUND');
    case 'P2003':
      return ApiError.badRequest('İlişkili kayıt bulunamadı', 'FOREIGN_KEY_ERROR');
    default:
      return ApiError.internal();
  }
}