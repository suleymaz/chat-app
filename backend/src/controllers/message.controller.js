import * as messageService from "../services/message.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { success, created, paginated } from "../utils/ApiResponse.js";

export const listele = asyncHandler(async (req, res) => {
  const { cursor, limit } = req.validatedQuery ?? req.query;
  const sonuc = await messageService.listele(req.user.id, req.params.id, { cursor, limit });
  paginated(res, sonuc.items, sonuc.nextCursor);
});

export const gonder = asyncHandler(async (req, res) => {
  const mesaj = await messageService.gonder(req.user, req.params.id, req.body);
  created(res, mesaj);
});

export const yeniSohbetBaslat = asyncHandler(async (req, res) => {
  const sonuc = await messageService.yeniSohbetBaslat(req.user, req.body);
  created(res, sonuc);
});

export const gorselGonder = asyncHandler(async (req, res) => {
  const mesaj = await messageService.gorselGonder(req.user, req.params.id, {
    content: req.body.content,
    dosya: req.file,
  });
  created(res, mesaj);
});

export const sil = asyncHandler(async (req, res) => {
  const mesaj = await messageService.sil(req.user.id, req.params.id);
  success(res, mesaj);
});

export const ara = asyncHandler(async (req, res) => {
  const { q, limit } = req.validatedQuery ?? req.query;
  const mesajlar = await messageService.ara(req.user.id, req.params.id, { q, limit });
  success(res, mesajlar);
});


export const dosyaGonder = asyncHandler(async (req, res) => {
  const mesaj = await messageService.dosyaGonder(req.user, req.params.id, {
    content: req.body.content,
    dosya: req.file,
  });
  created(res, mesaj);
});

// Ilk mesaji gorsel olarak gonderip sohbeti baslatir
export const yeniSohbetGorsel = asyncHandler(async (req, res) => {
  const sonuc = await messageService.yeniSohbetGorselGonder(req.user, {
    userId: req.body.userId,
    content: req.body.content,
    dosya: req.file,
  });
  created(res, sonuc);
});

// Ilk mesaji dosya olarak gonderip sohbeti baslatir
export const yeniSohbetDosya = asyncHandler(async (req, res) => {
  const sonuc = await messageService.yeniSohbetDosyaGonder(req.user, {
    userId: req.body.userId,
    content: req.body.content,
    dosya: req.file,
  });
  created(res, sonuc);
});