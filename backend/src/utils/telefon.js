// Telefon numaralari veritabaninda tek bicimde tutulur: 05XXXXXXXXX (11 hane).
// Kullanici +90'li, 90'li, basinda sifirsiz veya arada bosluk/tire olan bir
// numara girebilir; hepsi ayni kayda denk gelsin diye once normallestiriliyor.
// Aksi halde kayit sirasinda "+905551110001" yazan kullanici, girise
// "05551110001" yazdiginda hesabini bulamazdi.

const TEMIZ = /[\s()\-.]/g;

export const telefonNormalize = (deger) => {
  if (typeof deger !== "string") return "";

  const sade = deger.replace(TEMIZ, "");

  if (/^\+90\d{10}$/.test(sade)) return `0${sade.slice(3)}`;
  if (/^90\d{10}$/.test(sade)) return `0${sade.slice(2)}`;
  if (/^0\d{10}$/.test(sade)) return sade;
  if (/^\d{10}$/.test(sade)) return `0${sade}`;

  // Tanimadigimiz bicim oldugu gibi doner, dogrulama adimi eler
  return sade;
};

export const telefonGecerliMi = (deger) => /^0[0-9]{10}$/.test(deger);
