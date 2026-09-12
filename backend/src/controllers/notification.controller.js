import * as notificationService from "../services/notification.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { noContent } from "../utils/ApiResponse.js";

export const cihazKaydet = asyncHandler(async (req, res) => {
  await notificationService.cihazKaydet(req.user.id, req.body);
  noContent(res);
});

export const cihazSil = asyncHandler(async (req, res) => {
  await notificationService.cihazSil(req.user.id, req.body.fcmToken);
  noContent(res);
});