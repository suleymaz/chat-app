import { getIO, kullaniciSocketIdleri } from "../config/socket.js";

// Bir kullanicinin tum acik socket'lerine olay gonderir
const kullaniciyaGonder = (userId, olay, veri) => {
  const io = getIO();
  const soketler = kullaniciSocketIdleri(userId);

  for (const socketId of soketler) {
    io.to(socketId).emit(olay, veri);
  }
};

// Yeni mesaji aliciya iletir
export const yeniMesajYayinla = (aliciId, mesaj) => {
  kullaniciyaGonder(aliciId, "message:new", mesaj);
};

// Gonderene mesajin iletildigi bilgisini gonderir
export const iletildiYayinla = (gonderenId, { conversationId, messageIds, deliveredAt }) => {
  kullaniciyaGonder(gonderenId, "message:delivered", {
    conversationId,
    messageIds,
    deliveredAt,
  });
};

// Gonderene mesajlarin okundugu bilgisini gonderir
export const okunduYayinla = (gonderenId, { conversationId, readAt }) => {
  kullaniciyaGonder(gonderenId, "message:read", { conversationId, readAt });
};

// Silinen mesaji karsi tarafa bildirir
export const mesajSilindiYayinla = (aliciId, { conversationId, messageId }) => {
  kullaniciyaGonder(aliciId, "message:deleted", { conversationId, messageId });
};