import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { io as istemciAc } from 'socket.io-client';
import {
  API,
  api,
  kullaniciOlustur,
  prisma,
  sohbetOlustur,
  testSunucusu,
  veritabaniniBosalt,
} from './helpers.js';

let adres;
let ben;
let oteki;
let yabanci;
let sohbetId;

const acikSoketler = [];

// Baglanti kurulsa da kurulmasa da sonuc donuyor: reddedilme de test edilecek
const baglan = (token) =>
  new Promise((coz) => {
    const soket = istemciAc(adres, {
      auth: token === undefined ? {} : { token },
      transports: ['websocket'],
      reconnection: false,
    });

    acikSoketler.push(soket);
    soket.on('connect', () => coz({ soket, bagli: true }));
    soket.on('connect_error', () => coz({ soket, bagli: false }));
  });

const olayBekle = (soket, olay, sure = 4000) =>
  new Promise((coz, red) => {
    const zamanasimi = setTimeout(
      () => red(new Error(`"${olay}" olayi ${sure} ms icinde gelmedi`)),
      sure
    );

    soket.once(olay, (veri) => {
      clearTimeout(zamanasimi);
      coz(veri);
    });
  });

// Sunucu cevrimici bilgisini baglantidan hemen sonra asenkron yaziyor
const kosulBekle = async (kosul, sure = 3000) => {
  const bitis = Date.now() + sure;

  while (Date.now() < bitis) {
    if (await kosul()) return true;
    await new Promise((coz) => setTimeout(coz, 50));
  }

  return false;
};

const cevrimiciMi = async (userId) => {
  const kayit = await prisma.user.findUnique({
    where: { id: userId },
    select: { isOnline: true },
  });

  return kayit.isOnline;
};

before(async () => {
  await veritabaniniBosalt();
  await new Promise((coz) => testSunucusu.listen(0, coz));

  adres = `http://localhost:${testSunucusu.address().port}`;
  ben = await kullaniciOlustur();
  oteki = await kullaniciOlustur();
  yabanci = await kullaniciOlustur();
  sohbetId = await sohbetOlustur(ben, oteki, 'ilk mesaj');
});

after(async () => {
  for (const soket of acikSoketler) {
    soket.disconnect();
  }

  await new Promise((coz) => testSunucusu.close(coz));
  await prisma.$disconnect();
});

describe('socket kimlik dogrulama', () => {
  it('tokensiz baglanti reddedilir', async () => {
    const { bagli } = await baglan(undefined);

    assert.equal(bagli, false);
  });

  it('bozuk token reddedilir', async () => {
    const { bagli } = await baglan('bozuk.token.xyz');

    assert.equal(bagli, false);
  });

  it('gecerli token ile baglanilir ve kullanici cevrimici isaretlenir', async () => {
    const { bagli } = await baglan(ben.token);

    assert.equal(bagli, true);
    assert.ok(await kosulBekle(() => cevrimiciMi(ben.id)), 'kullanici cevrimici olmadi');
  });
});

describe('canli mesajlasma', () => {
  let benimSoketim;
  let otekininSoketi;

  before(async () => {
    benimSoketim = (await baglan(ben.token)).soket;
    otekininSoketi = (await baglan(oteki.token)).soket;

    benimSoketim.emit('conversation:join', { conversationId: sohbetId });
    otekininSoketi.emit('conversation:join', { conversationId: sohbetId });

    await new Promise((coz) => setTimeout(coz, 300));
  });

  it('gonderilen mesaj karsi tarafa aninda ulasir', async () => {
    const bekleyen = olayBekle(otekininSoketi, 'message:new');

    const gonderim = await api()
      .post(`${API}/conversations/${sohbetId}/messages`)
      .set('Authorization', `Bearer ${ben.token}`)
      .send({ content: 'canli mesaj' });

    const gelen = await bekleyen;

    assert.equal(gelen.content, 'canli mesaj');
    assert.equal(gelen.id, gonderim.body.data.id);
  });

  it('karsi taraf bagliyken gonderene iletildi bilgisi doner', async () => {
    const bekleyen = olayBekle(benimSoketim, 'message:delivered');

    await api()
      .post(`${API}/conversations/${sohbetId}/messages`)
      .set('Authorization', `Bearer ${ben.token}`)
      .send({ content: 'iletildi denemesi' });

    const bilgi = await bekleyen;

    assert.equal(bilgi.conversationId, sohbetId);
  });

  it('okundu bilgisi gonderene ulasir', async () => {
    const bekleyen = olayBekle(benimSoketim, 'message:read');

    await api()
      .post(`${API}/conversations/${sohbetId}/read`)
      .set('Authorization', `Bearer ${oteki.token}`);

    const bilgi = await bekleyen;

    assert.equal(bilgi.conversationId, sohbetId);
  });

  it('yaziyor gostergesi yalnizca sohbet odasina gider', async () => {
    const bekleyen = olayBekle(otekininSoketi, 'typing');

    benimSoketim.emit('typing:start', { conversationId: sohbetId });
    const bilgi = await bekleyen;

    assert.equal(bilgi.isTyping, true);
    assert.equal(bilgi.userId, ben.id);
  });

  // Odaya katilma istegi sunucuda katilimcilik kontrolunden geciyor; gecmezse
  // istek sessizce yok sayiliyor ve kullanici sohbetin trafigini goremiyor.
  it('katilimci olmayan kullanici sohbet odasina giremez', async () => {
    const yabancininSoketi = (await baglan(yabanci.token)).soket;
    yabancininSoketi.emit('conversation:join', { conversationId: sohbetId });
    await new Promise((coz) => setTimeout(coz, 300));

    let duyulanMesaj = null;
    yabancininSoketi.on('message:new', (veri) => {
      duyulanMesaj = veri;
    });

    await api()
      .post(`${API}/conversations/${sohbetId}/messages`)
      .set('Authorization', `Bearer ${ben.token}`)
      .send({ content: 'gizli mesaj' });

    await new Promise((coz) => setTimeout(coz, 600));

    assert.equal(duyulanMesaj, null, 'yabanci kullanici sohbet mesajini aldi');
  });
});

describe('cevrimdisi olma', () => {
  it('baglanti kopunca kullanici cevrimdisi olur ve son gorulme yazilir', async () => {
    const kullanici = await kullaniciOlustur();
    const { soket } = await baglan(kullanici.token);

    assert.ok(await kosulBekle(() => cevrimiciMi(kullanici.id)));

    soket.disconnect();

    assert.ok(
      await kosulBekle(async () => !(await cevrimiciMi(kullanici.id))),
      'kullanici cevrimdisi olmadi'
    );

    const kayit = await prisma.user.findUnique({
      where: { id: kullanici.id },
      select: { lastSeenAt: true },
    });

    assert.ok(kayit.lastSeenAt);
  });
});
