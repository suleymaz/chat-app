// Test dosyalarinin ortak kullandigi kisayollar.
import http from 'node:http';
import request from 'supertest';
import app from '../src/app.js';
import prisma from '../src/config/database.js';
import { initSocket } from '../src/config/socket.js';

// Mesaj servisi yayinlarini getIO() uzerinden yapiyor; Socket.IO baslatilmazsa
// mesaj gondermek 500 donuyor. Gercek sunucudaki kurulumun aynisi yapiliyor.
// Dinlemeye gerek yok, supertest istekleri dogrudan app'e veriyor; yalnizca
// socket testleri bu sunucuyu bir porta bagliyor.
export const testSunucusu = http.createServer(app);
initSocket(testSunucusu);

export const API = '/api/v1';
export const SIFRE = 'Test1234!';

export const api = () => request(app);

// Her test dosyasi kendi surecinde calistigi icin tablolari bosaltmak
// testleri hem birbirinden hem de gelistirme verisinden bagimsiz tutuyor.
export const veritabaniniBosalt = async () => {
  await prisma.$executeRawUnsafe(
    'TRUNCATE TABLE "Block", "Attachment", "Message", "ConversationParticipant", ' +
      '"Conversation", "DeviceToken", "RefreshToken", "User" RESTART IDENTITY CASCADE'
  );
};

let sayac = 0;

// Gercek kayit ucunu kullaniyor: boylece token uretimi de her testte dogrulanmis oluyor
export const kullaniciOlustur = async (ekBilgi = {}) => {
  sayac += 1;
  const sira = String(sayac).padStart(4, '0');

  const bilgi = {
    username: `kullanici${sira}`,
    email: `kullanici${sira}@test.com`,
    phone: `0555000${sira}`,
    fullName: `Test Kullanici ${sira}`,
    password: SIFRE,
    ...ekBilgi,
  };

  const yanit = await api().post(`${API}/auth/register`).send(bilgi);

  if (yanit.status !== 201) {
    throw new Error(`Test kullanicisi olusturulamadi: ${JSON.stringify(yanit.body)}`);
  }

  return {
    ...yanit.body.data.user,
    sifre: bilgi.password,
    token: yanit.body.data.accessToken,
    refreshToken: yanit.body.data.refreshToken,
  };
};

// Ilk mesajla birlikte sohbeti olusturur, sohbet id'sini dondurur
export const sohbetOlustur = async (gonderen, alici, icerik = 'merhaba') => {
  const yanit = await api()
    .post(`${API}/messages`)
    .set('Authorization', `Bearer ${gonderen.token}`)
    .send({ userId: alici.id, content: icerik });

  if (yanit.status !== 201) {
    throw new Error(`Test sohbeti olusturulamadi: ${JSON.stringify(yanit.body)}`);
  }

  return yanit.body.data.conversationId;
};

// sharp'in isleyebilecegi en kucuk gecerli PNG (1x1 piksel)
export const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64'
);

export { prisma };
