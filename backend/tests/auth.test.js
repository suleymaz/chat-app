import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { API, SIFRE, api, kullaniciOlustur, prisma, veritabaniniBosalt } from './helpers.js';

const KAYIT = {
  username: 'ayse',
  email: 'ayse@test.com',
  phone: '05551110001',
  fullName: 'Ayse Yilmaz',
  password: SIFRE,
};

before(veritabaniniBosalt);
after(() => prisma.$disconnect());

describe('kayit', () => {
  it('gecerli bilgilerle kullanici olusturur', async () => {
    const yanit = await api().post(`${API}/auth/register`).send(KAYIT);

    assert.equal(yanit.status, 201);
    assert.ok(yanit.body.data.accessToken);
    assert.ok(yanit.body.data.refreshToken);
    assert.equal(yanit.body.data.user.username, KAYIT.username);
  });

  it('yanitta sifre ozeti sizdirmaz', async () => {
    const yanit = await api()
      .post(`${API}/auth/register`)
      .send({ ...KAYIT, username: 'mehmet', email: 'mehmet@test.com', phone: '05551110002' });

    assert.equal(JSON.stringify(yanit.body).includes('passwordHash'), false);
  });

  it('kullanilan kullanici adi, e-posta ve telefonu reddeder', async () => {
    const durumlar = [
      ['kullanici adi', { ...KAYIT, email: 'baska@test.com', phone: '05551110009' }],
      ['e-posta', { ...KAYIT, username: 'baska', phone: '05551110009' }],
      ['telefon', { ...KAYIT, username: 'baska', email: 'baska@test.com' }],
    ];

    for (const [alan, govde] of durumlar) {
      const yanit = await api().post(`${API}/auth/register`).send(govde);
      assert.equal(yanit.status, 409, `${alan} icin 409 bekleniyordu`);
    }
  });

  it('gecersiz alanlari dogrulama hatasiyla reddeder', async () => {
    const durumlar = [
      ['kisa sifre', { password: 'Ab1' }],
      ['rakamsiz sifre', { password: 'Abcdefgh' }],
      ['buyuk harfsiz sifre', { password: 'abcdefg1' }],
      ['bozuk e-posta', { email: 'bozuk' }],
      ['eksik haneli telefon', { phone: '123' }],
      ['buyuk harfli kullanici adi', { username: 'BuyukHarf' }],
      ['cok kisa ad soyad', { fullName: 'A' }],
    ];

    for (const [ad, degisiklik] of durumlar) {
      const govde = {
        ...KAYIT,
        username: 'gecici',
        email: 'gecici@test.com',
        phone: '05559990000',
        ...degisiklik,
      };

      const yanit = await api().post(`${API}/auth/register`).send(govde);
      assert.equal(yanit.status, 400, `${ad} icin 400 bekleniyordu`);
    }
  });

  it('sifreyi duz metin olarak saklamaz', async () => {
    const kayit = await prisma.user.findUnique({ where: { username: KAYIT.username } });

    assert.notEqual(kayit.passwordHash, SIFRE);
    assert.match(kayit.passwordHash, /^\$2[aby]\$\d{2}\$/);
    assert.ok(Number(kayit.passwordHash.split('$')[2]) >= 10, 'bcrypt maliyeti en az 10 olmali');
  });
});

describe('giris', () => {
  it('kullanici adi, e-posta ve iki telefon biciminde calisir', async () => {
    const kimlikler = [
      ['kullanici adi', KAYIT.username],
      ['e-posta', KAYIT.email],
      ['telefon 05XXXXXXXXX', KAYIT.phone],
      ['telefon +90XXXXXXXXXX', `+90${KAYIT.phone.slice(1)}`],
    ];

    for (const [ad, identifier] of kimlikler) {
      const yanit = await api().post(`${API}/auth/login`).send({ identifier, password: SIFRE });
      assert.equal(yanit.status, 200, `${ad} ile giris yapilamadi`);
    }
  });

  it('yanlis sifreyi reddeder ve kullanicinin varligini sizdirmaz', async () => {
    const yanlisSifre = await api()
      .post(`${API}/auth/login`)
      .send({ identifier: KAYIT.username, password: 'Yanlis123!' });

    const olmayanKullanici = await api()
      .post(`${API}/auth/login`)
      .send({ identifier: 'hicyok', password: SIFRE });

    assert.equal(yanlisSifre.status, 401);
    assert.equal(olmayanKullanici.status, 401);
    assert.equal(yanlisSifre.body.error.message, olmayanKullanici.body.error.message);
  });
});

describe('token yenileme', () => {
  it('yenilemede refresh token dondurulur ve eskisi gecersiz kalir', async () => {
    const kullanici = await kullaniciOlustur();

    const ilk = await api()
      .post(`${API}/auth/refresh`)
      .send({ refreshToken: kullanici.refreshToken });

    assert.equal(ilk.status, 200);
    assert.notEqual(ilk.body.data.refreshToken, kullanici.refreshToken);

    const tekrar = await api()
      .post(`${API}/auth/refresh`)
      .send({ refreshToken: kullanici.refreshToken });

    assert.equal(tekrar.status, 401, 'harcanmis token kabul edilmemeli');
  });

  it('yeniden kullanim tespit edilince tum zinciri iptal eder', async () => {
    const kullanici = await kullaniciOlustur();

    const ilk = await api()
      .post(`${API}/auth/refresh`)
      .send({ refreshToken: kullanici.refreshToken });

    // Eski token'in tekrar kullanilmasi calinma belirtisi sayiliyor
    await api().post(`${API}/auth/refresh`).send({ refreshToken: kullanici.refreshToken });

    const zincir = await api()
      .post(`${API}/auth/refresh`)
      .send({ refreshToken: ilk.body.data.refreshToken });

    assert.equal(zincir.status, 401, 'zincirdeki gecerli token da iptal edilmeliydi');
  });

  it('refresh token access token yerine kullanilamaz', async () => {
    const kullanici = await kullaniciOlustur();

    const yanit = await api()
      .get(`${API}/users/me`)
      .set('Authorization', `Bearer ${kullanici.refreshToken}`);

    assert.equal(yanit.status, 401);
  });
});

describe('yetkilendirme', () => {
  it('korumali uclar token olmadan 401 doner', async () => {
    const uclar = [
      ['get', `${API}/users/me`],
      ['patch', `${API}/users/me`],
      ['get', `${API}/users/search?q=ab`],
      ['get', `${API}/conversations`],
      ['post', `${API}/messages`],
      ['get', `${API}/users/me/blocked`],
      ['post', `${API}/notifications/token`],
      ['delete', `${API}/users/me/avatar`],
    ];

    for (const [yontem, yol] of uclar) {
      const yanit = await api()[yontem](yol);
      assert.equal(yanit.status, 401, `${yontem.toUpperCase()} ${yol} korumasiz`);
    }
  });

  it('bozuk token reddedilir', async () => {
    const yanit = await api().get(`${API}/users/me`).set('Authorization', 'Bearer bozuk.token.xyz');

    assert.equal(yanit.status, 401);
  });
});
