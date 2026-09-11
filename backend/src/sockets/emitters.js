import { getIO } from "../config/socket.js";

// Yeni mesaji aliciya iletir
export const yeniMesajYayinla = (aliciId, mesaj) => {
  getIO().to(`user:${aliciId}`).emit("message:new", mesaj);
};

// Gonderene mesajin iletildigi bilgisini gonderir
export const iletildiYayinla = (gonderenId, { conversationId, messageIds, deliveredAt }) => {
  getIO().to(`user:${gonderenId}`).emit("message:delivered", {
    conversationId,
    messageIds,
    deliveredAt,
  });
};

// Gonderene mesajlarin okundugu bilgisini gonderir
export const okunduYayinla = (gonderenId, { conversationId, readAt }) => {
  getIO().to(`user:${gonderenId}`).emit("message:read", {
    conversationId,
    readAt,
  });
};

// Silinen mesaji karsi tarafa bildirir
export const mesajSilindiYayinla = (aliciId, { conversationId, messageId }) => {
  getIO().to(`user:${aliciId}`).emit("message:deleted", {
    conversationId,
    messageId,
  });
};