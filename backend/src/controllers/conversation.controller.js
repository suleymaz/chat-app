import * as conversationService from "../services/conversation.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { success, noContent } from "../utils/ApiResponse.js";

export const listele = asyncHandler(async (req, res) => {
  const archived = req.query.archived === "true";
  const sohbetler = await conversationService.listele(req.user.id, { archived });
  success(res, sohbetler);
});

export const detay = asyncHandler(async (req, res) => {
  const sohbet = await conversationService.detay(req.user.id, req.params.id);
  success(res, sohbet);
});

export const kullaniciylaSohbet = asyncHandler(async (req, res) => {
  const sohbet = await conversationService.kullaniciylaSohbet(req.user.id, req.body.userId);
  success(res, sohbet);
});

export const okunduIsaretle = asyncHandler(async (req, res) => {
  await conversationService.okunduIsaretle(req.user.id, req.params.id);
  noContent(res);
});

export const arsivle = asyncHandler(async (req, res) => {
  await conversationService.arsivle(req.user.id, req.params.id, req.body.archived);
  noContent(res);
});

export const sessizeAl = asyncHandler(async (req, res) => {
  await conversationService.sessizeAl(req.user.id, req.params.id, req.body.muted);
  noContent(res);
});

export const sil = asyncHandler(async (req, res) => {
  await conversationService.sil(req.user.id, req.params.id);
  noContent(res);
});