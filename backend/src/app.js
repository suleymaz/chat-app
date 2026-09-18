import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import path from "path";
import routes from './routes/index.js';
import { env } from './config/env.js';
import logger from './utils/logger.js';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler.js';
import { generalLimiter } from './middlewares/rateLimit.js';
import { corsOrigin } from './config/cors.js';

const app = express();

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: "cross-origin" },
  })
);
app.use(cors({ origin: corsOrigin(), credentials: false }));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

app.use(
  morgan(env.NODE_ENV === 'development' ? 'dev' : 'combined', {
    stream: { write: (message) => logger.info(message.trim()) },
  })
);

// Yuklenen dosyalar statik olarak servis edilir
app.use(`/${env.UPLOAD_DIR}`, express.static(path.join(process.cwd(), env.UPLOAD_DIR)));

app.get('/health', (req, res) => {
  res.json({
    success: true,
    data: {
      status: 'ok',
      environment: env.NODE_ENV,
      timestamp: new Date().toISOString(),
    },
  });
});

// Genel istek siniri - auth uclarindaki daha siki limit ayrica uygulanir
app.use('/api/v1', generalLimiter, routes);

app.use(notFoundHandler);
app.use(errorHandler);

export default app;