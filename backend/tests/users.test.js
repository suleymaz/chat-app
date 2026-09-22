import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { API, SIFRE, api, kullaniciOlustur, prisma, veritabaniniBosalt } from './helpers.js';

let ben;
let oteki;

const benimIstegim = (yontem, yol) =>
  api()[yontem](`${API}${yol}`).set('Authorization', `Bearer ${ben.token}`);

before(async () => {
  await veritabaniniBosalt();
  ben = await kullaniciOlustur();
  oteki = await kullaniciOlustur();
});

after(() => prisma.$disconnect());

describe('profil goruntuleme', () => {
  it('kendi profilini beklenen alanlarla doner', async () => {
    const yanit = await benimIstegim('get', '/users/me');

    assert.equal(yanit.status, 200);
    for (const alan of ['id', 'username', 'email', 'phone', 'fullName', 'notificationPreview']) {
      assert.ok(alan in yanit.body.data, `${alan} alani eksik`);
    }
    assert.equal(JSON.stringify(yanit.body).includes('passwordHash'), false);
  });

  it('baskasinin profilini iletisim bilgileriyle doner', async () => {
    const yanit = await benimIstegim('get', `/users/${oteki.id}`);

    assert.equal(yanit.status, 200);
    assert.ok(yanit.body.data.phone);
    assert.ok(yanit.body.data.email);
  });

  it('olmayan kullanici 404, gecersiz uuid 400 doner', async () => {
    const yok = await benimIstegim('get', '/users/00000000-0000-0000-0000-000000000000');
    const bozuk = await benimIstegim('get', '/users/abc');

    assert.equal(yok.status, 404);
    assert.equal(bozuk.status, 400);
  });
});

describe('profil guncelleme', () => {
  it('ad soyad degisikligi sifre istemez', async () => {
    const yanit = await benimIstegim('patch', '/users/me').send({ fullName: 'Yeni Ad Soyad' });

    assert.equal(yanit.status, 200);
    assert.equal(yanit.body.data.fullName, 'Yeni Ad Soyad');
  });

  // Kimlik alanlari sifresiz degisebilseydi, acik kalan bir oturumu ele geciren
  // biri kullanici adini ve e-postayi degistirip hesabi tamamen devralabilirdi.
  it('kimlik alanlari sifre olmadan degistirilemez', async () => {
    for (const govde of [{ username: 'yenikullanici' }, { email: 'yeni@test.com' }, { phone: '05557770001' }]) {
      const yanit = await benimIstegim('patch', '/users/me').send(govde);
      assert.equal(yanit.status, 400, `${Object.keys(govde)[0]} sifresiz degisti`);
    }
  });

  it('yanlis sifreyle kimlik alani degistirilemez', async () => {
    const yanit = await benimIstegim('patch', '/users/me').send({
      email: 'yeni@test.com',
      currentPassword: 'Yanlis123!',
    });

    assert.equal(yanit.status, 401);
  });

  it('baskasinin e-postasi veya telefonu alinamaz', async () => {
    const eposta = await benimIstegim('patch', '/users/me').send({
      email: oteki.email,
      currentPassword: SIFRE,
    });
    const telefon = await benimIstegim('patch', '/users/me').send({
      phone: oteki.phone,
      currentPassword: SIFRE,
    });

    assert.equal(eposta.status, 409);
    assert.equal(telefon.status, 409);
  });

  it('dogru sifreyle e-posta degisir ve yeni e-postayla giris yapilir', async () => {
    const yeniEposta = 'degismis@test.com';

    const guncelleme = await benimIstegim('patch', '/users/me').send({
      email: yeniEposta,
      currentPassword: SIFRE,
    });
    assert.equal(guncelleme.status, 200);

    const giris = await api()
      .post(`${API}/auth/login`)
      .send({ identifier: yeniEposta, password: SIFRE });
    assert.equal(giris.status, 200);

    ben.email = yeniEposta;
  });

  it('bos govde, uzun bio ve gecersiz enum reddedilir', async () => {
    const durumlar = [
      ['bos govde', {}],
      ['160 karakterden uzun bio', { bio: 'x'.repeat(200) }],
      ['gecersiz bildirim onizlemesi', { notificationPreview: 'GECERSIZ' }],
    ];

    for (const [ad, govde] of durumlar) {
      const yanit = await benimIstegim('patch', '/users/me').send(govde);
      assert.equal(yanit.status, 400, `${ad} kabul edildi`);
    }
  });
});

describe('sifre degistirme', () => {
  it('yanlis mevcut sifre ve zayif yeni sifre reddedilir', async () => {
    const yanlis = await benimIstegim('patch', '/users/me/password').send({
      currentPassword: 'Yanlis123!',
      newPassword: 'YeniSifre1!',
    });
    const zayif = await benimIstegim('patch', '/users/me/password').send({
      currentPassword: SIFRE,
      newPassword: 'zayif',
    });

    assert.equal(yanlis.status, 401);
    assert.equal(zayif.status, 400);
  });

  it('sifre degisince eski sifreyle giris yapilamaz', async () => {
    const kullanici = await kullaniciOlustur();
    const yeniSifre = 'YeniSifre1!';

    const degisim = await api()
      .patch(`${API}/users/me/password`)
      .set('Authorization', `Bearer ${kullanici.token}`)
      .send({ currentPassword: SIFRE, newPassword: yeniSifre });
    assert.equal(degisim.status, 204);

    const eski = await api()
      .post(`${API}/auth/login`)
      .send({ identifier: kullanici.username, password: SIFRE });
    const yeni = await api()
      .post(`${API}/auth/login`)
      .send({ identifier: kullanici.username, password: yeniSifre });

    assert.equal(eski.status, 401);
    assert.equal(yeni.status, 200);
  });
});

describe('kullanici arama', () => {
  it('kullanici adi, e-posta ve telefonla sonuc doner', async () => {
    const aramalar = [oteki.username, oteki.email, oteki.phone];

    for (const q of aramalar) {
      const yanit = await benimIstegim('get', `/users/search?q=${encodeURIComponent(q)}`);
      assert.equal(yanit.status, 200);
      assert.ok(
        yanit.body.data.some((k) => k.id === oteki.id),
        `"${q}" aramasi kullaniciyi bulamadi`
      );
    }
  });

  it('arayan kendisi sonuclarda cikmaz', async () => {
    const yanit = await benimIstegim('get', `/users/search?q=${ben.username}`);

    assert.equal(
      yanit.body.data.some((k) => k.id === ben.id),
      false
    );
  });

  it('sonuclarda e-posta gibi iletisim bilgisi sizmaz', async () => {
    const yanit = await benimIstegim('get', `/users/search?q=${oteki.username}`);

    assert.equal(
      yanit.body.data.some((k) => 'email' in k),
      false
    );
  });

  it('tek karakterli arama reddedilir', async () => {
    const yanit = await benimIstegim('get', '/users/search?q=a');

    assert.equal(yanit.status, 400);
  });
});

describe('engelleme', () => {
  it('kullanici engellenir, tekrar engelleme ve kendini engelleme reddedilir', async () => {
    const engelle = await benimIstegim('post', `/users/${oteki.id}/block`);
    const tekrar = await benimIstegim('post', `/users/${oteki.id}/block`);
    const kendisi = await benimIstegim('post', `/users/${ben.id}/block`);

    assert.equal(engelle.status, 201);
    assert.equal(tekrar.status, 409);
    assert.equal(kendisi.status, 400);
  });

  it('engellenen kullanici listede gorunur', async () => {
    const yanit = await benimIstegim('get', '/users/me/blocked');

    assert.ok(yanit.body.data.some((k) => k.id === oteki.id));
  });

  it('engellenen kullanici profilde ve aramada gorunmez', async () => {
    const profil = await benimIstegim('get', `/users/${oteki.id}`);
    const arama = await benimIstegim('get', `/users/search?q=${oteki.username}`);

    assert.equal(profil.status, 404);
    assert.equal(
      arama.body.data.some((k) => k.id === oteki.id),
      false
    );
  });

  it('engel kaldirilir, engelli olmayanda 404 doner', async () => {
    const kaldir = await benimIstegim('delete', `/users/${oteki.id}/block`);
    const tekrar = await benimIstegim('delete', `/users/${oteki.id}/block`);

    assert.equal(kaldir.status, 204);
    assert.equal(tekrar.status, 404);
  });
});
