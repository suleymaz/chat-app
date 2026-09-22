// Testler gelistirme veritabanina asla dokunmamali. Ayri bir .env.test dosyasi
// tutmak yerine .env icindeki baglantiyi okuyup yalnizca veritabani adini
// degistiriyoruz: boylece tek yapilandirma dosyasi kaliyor, depoya sifre
// girmek gerekmiyor ve testin yanlislikla gercek veriyi silmesi mumkun olmuyor.
import dotenv from 'dotenv';

dotenv.config({ quiet: true });

export const TEST_VERITABANI = 'chatapp_test';

export const testVeritabaniUrl = () => {
  const ham = process.env.DATABASE_URL;

  if (!ham) {
    throw new Error('DATABASE_URL tanimli degil. Once backend/.env dosyasini olusturun.');
  }

  const url = new URL(ham);
  url.pathname = `/${TEST_VERITABANI}`;
  return url.toString();
};
