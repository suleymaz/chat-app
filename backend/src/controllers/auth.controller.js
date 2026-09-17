import * as authService from '../services/auth.service.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { success, created, noContent } from '../utils/ApiResponse.js';

export const register = asyncHandler(async (req, res) => {
  const result = await authService.register(req.body);
  created(res, result);
});

export const login = asyncHandler(async (req, res) => {
  const result = await authService.login(req.body);
  success(res, result);
});

export const refresh = asyncHandler(async (req, res) => {
  const result = await authService.refresh(req.body.refreshToken);
  success(res, result);
});

export const logout = asyncHandler(async (req, res) => {
  await authService.logout(req.body.refreshToken, req.user?.id);
  noContent(res);
});