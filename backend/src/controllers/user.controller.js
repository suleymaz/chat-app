import * as userService from "../services/user.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { success, noContent, created } from "../utils/ApiResponse.js";

export const getMe = asyncHandler(async (req, res) => {
  const kullanici = await userService.getMyProfile(req.user.id);
  success(res, kullanici);
});

export const updateMe = asyncHandler(async (req, res) => {
  const kullanici = await userService.updateProfile(req.user.id, req.body);
  success(res, kullanici);
});

export const changePassword = asyncHandler(async (req, res) => {
  await userService.changePassword(req.user.id, req.body);
  noContent(res);
});

export const searchUsers = asyncHandler(async (req, res) => {
  const sonuclar = await userService.searchUsers(req.user.id, req.validatedQuery ?? req.query);
  success(res, sonuclar);
});

export const getUserById = asyncHandler(async (req, res) => {
  const profil = await userService.getUserProfile(req.user.id, req.params.id);
  success(res, profil);
});

export const blockUser = asyncHandler(async (req, res) => {
  await userService.blockUser(req.user.id, req.params.id);
  created(res, { blocked: true });
});

export const unblockUser = asyncHandler(async (req, res) => {
  await userService.unblockUser(req.user.id, req.params.id);
  noContent(res);
});

export const getBlockedUsers = asyncHandler(async (req, res) => {
  const liste = await userService.getBlockedUsers(req.user.id);
  success(res, liste);
});