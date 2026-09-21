import { ApiError } from '../utils/ApiError.js';

export const validate = (schema) => (req, res, next) => {
  const result = schema.safeParse({
    body: req.body,
    query: req.query,
    params: req.params,
  });

  if (!result.success) {
    const details = result.error.issues.map((issue) => ({
      field: issue.path.slice(1).join('.'),
      message: issue.message,
    }));

    return next(ApiError.badRequest('Gönderilen veriler geçersiz', 'VALIDATION_ERROR', details));
  }

  if (result.data.body) req.body = result.data.body;
  if (result.data.params) req.params = result.data.params;


  // Express 4'te req.query salt okunur oldugu icin dogrulanmis degerler
  // ayri bir alanda tutuluyor
  if (result.data.query) req.validatedQuery = result.data.query;


  next();
};