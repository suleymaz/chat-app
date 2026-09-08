export const success = (res, data, statusCode = 200) => {
  return res.status(statusCode).json({
    success: true,
    data,
  });
};

export const created = (res, data) => success(res, data, 201);

export const noContent = (res) => res.status(204).send();

export const paginated = (res, items, nextCursor = null) => {
  return res.status(200).json({
    success: true,
    data: {
      items,
      nextCursor,
      hasMore: nextCursor !== null,
    },
  });
};