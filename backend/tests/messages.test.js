import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {
  API,
  PNG,
  api,
  kullaniciOlustur,
  prisma,
  sohbetOlustur,
  veritabaniniBosalt,
} from './helpers.js';

let ben;
let oteki;
let yabanci;
let sohbetId;

const istek = (kullanici, yontem, yol) =>
  api()[yontem](`${API}${yol}`).set('Authorization', `Bearer ${kullanici.token}`);

const mesajGonder = (kullanici, icerik) =>
  istek(kullanici, 'post', `/conversations/${sohbetId}/messages`).send({ content: icerik });

before(async () => {
  await veritabaniniBosalt();
  ben = await kullaniciOlustur();
  oteki = await kullaniciOlustur();
  yabanci = await kullaniciOlustur();
  sohbetId = await sohbetOlustur(ben, oteki, 'ilk mesaj');
});

after(() => prisma.$disconnect());

describe('sohbet baslatma', () => {
  it('ilk mesajla birlikte sohbet olusur', async () => {
    assert.ok(sohbetId);
  });

  it('var olan sohbet tekrar acildiginda yeni olusturulmaz', async () => {
    const yanit = await istek(ben, 'post', '/conversations/with-user').send({ userId: oteki.id });

    assert.equal(yanit.status, 200);
    assert.equal(yanit.body.data.id, sohbetId);
    assert.equal(yanit.body.data.isNew, false);
  });

  it('kullanici kendisiyle sohbet acamaz', async () => {
    const yanit = await istek(ben, 'post', '/conversations/with-user').send({ userId: ben.id });

    assert.equal(yanit.status, 400);
  });
});

describe('sohbet listesi ve detayi', () => {
  it('listede son mesaj ve karsi taraf bilgisi bulunur', async () => {
    const yanit = await istek(ben, 'get', '/conversations');
    const kayit = yanit.body.data.find((s) => s.id === sohbetId);

    assert.equal(yanit.status, 200);
    assert.equal(kayit.lastMessage.content, 'ilk mesaj');
    assert.equal(kayit.user.id, oteki.id);
  });

  it('okunmamis sayisi yalnizca alicida artar', async () => {
    const gonderen = await istek(ben, 'get', '/conversations');
    const alici = await istek(oteki, 'get', '/conversations');

    assert.equal(gonderen.body.data.find((s) => s.id === sohbetId).unreadCount, 0);
    assert.equal(alici.body.data.find((s) => s.id === sohbetId).unreadCount, 1);
  });

  it('detayda engel ve sessize alma durumu doner', async () => {
    const yanit = await istek(ben, 'get', `/conversations/${sohbetId}`);

    assert.equal(yanit.status, 200);
    assert.ok('isBlocked' in yanit.body.data);
    assert.ok('isMuted' in yanit.body.data);
  });
});

describe('mesaj dogrulama', () => {
  it('bos, yalnizca bosluk ve sinir ustu icerik reddedilir', async () => {
    const durumlar = [
      ['bos mesaj', '', 400],
      ['yalnizca bosluk', '   ', 400],
      ['4001 karakter', 'x'.repeat(4001), 400],
      ['4000 karakter', 'x'.repeat(4000), 201],
    ];

    for (const [ad, icerik, beklenen] of durumlar) {
      const yanit = await mesajGonder(ben, icerik);
      assert.equal(yanit.status, beklenen, `${ad} icin ${beklenen} bekleniyordu`);

      if (yanit.status === 201) {
        await istek(ben, 'delete', `/messages/${yanit.body.data.id}`);
      }
    }
  });

  it('bozuk JSON govdesi 500 yerine 400 doner', async () => {
    const yanit = await api()
      .post(`${API}/auth/login`)
      .set('Content-Type', 'application/json')
      .send('{bozuk json');

    assert.equal(yanit.status, 400);
    assert.equal(yanit.body.success, false);
    assert.equal('stack' in yanit.body.error, false, 'hata yanitinda yigin izi sizmamali');
  });
});

describe('sayfalama', () => {
  let sayfaSohbeti;

  before(async () => {
    const a = await kullaniciOlustur();
    const b = await kullaniciOlustur();
    sayfaSohbeti = await sohbetOlustur(a, b, 'sayfalama 0');

    for (let i = 1; i <= 35; i += 1) {
      await api()
        .post(`${API}/conversations/${sayfaSohbeti}/messages`)
        .set('Authorization', `Bearer ${a.token}`)
        .send({ content: `sayfalama ${i}` });
    }

    ben.sayfaToken = a.token;
  });

  it('ilk sayfa 30 mesaj ve imlec doner, en yeni mesaj basta gelir', async () => {
    const yanit = await api()
      .get(`${API}/conversations/${sayfaSohbeti}/messages`)
      .set('Authorization', `Bearer ${ben.sayfaToken}`);

    assert.equal(yanit.body.data.items.length, 30);
    assert.equal(yanit.body.data.hasMore, true);
    assert.ok(yanit.body.data.nextCursor);
    assert.equal(yanit.body.data.items[0].content, 'sayfalama 35');
  });

  it('ikinci sayfa birinciyle cakismaz', async () => {
    const ilk = await api()
      .get(`${API}/conversations/${sayfaSohbeti}/messages`)
      .set('Authorization', `Bearer ${ben.sayfaToken}`);

    const ikinci = await api()
      .get(
        `${API}/conversations/${sayfaSohbeti}/messages?cursor=${encodeURIComponent(
          ilk.body.data.nextCursor
        )}`
      )
      .set('Authorization', `Bearer ${ben.sayfaToken}`);

    const kesisim = ilk.body.data.items.filter((m) =>
      ikinci.body.data.items.some((n) => n.id === m.id)
    );

    assert.ok(ikinci.body.data.items.length > 0);
    assert.equal(kesisim.length, 0);
  });

  it('sohbet icinde mesaj aramasi calisir', async () => {
    const yanit = await api()
      .get(`${API}/conversations/${sayfaSohbeti}/messages/search?q=${encodeURIComponent('sayfalama 12')}`)
      .set('Authorization', `Bearer ${ben.sayfaToken}`);

    assert.equal(yanit.status, 200);
    assert.ok(yanit.body.data.some((m) => m.content === 'sayfalama 12'));
  });
});

describe('okundu bilgisi', () => {
  it('okundu isaretlenince sayac sifirlanir ve gonderen readAt gorur', async () => {
    const okundu = await istek(oteki, 'post', `/conversations/${sohbetId}/read`);
    assert.equal(okundu.status, 204);

    const liste = await istek(oteki, 'get', '/conversations');
    assert.equal(liste.body.data.find((s) => s.id === sohbetId).unreadCount, 0);

    const mesajlar = await istek(ben, 'get', `/conversations/${sohbetId}/messages`);
    assert.ok(mesajlar.body.data.items[0].readAt);
  });
});

describe('mesaj silme', () => {
  it('kullanici yalnizca kendi mesajini silebilir', async () => {
    const gonderilen = await mesajGonder(ben, 'silinecek mesaj');
    const mesajId = gonderilen.body.data.id;

    const baskasi = await istek(oteki, 'delete', `/messages/${mesajId}`);
    assert.equal(baskasi.status, 403);

    const kendisi = await istek(ben, 'delete', `/messages/${mesajId}`);
    assert.equal(kendisi.status, 200);
    assert.equal(kendisi.body.data.content ?? null, null, 'silinen mesajin icerigi temizlenmeli');
    assert.ok(kendisi.body.data.deletedAt);
  });

  it('olmayan mesaj icin 404 doner', async () => {
    const yanit = await istek(ben, 'delete', '/messages/00000000-0000-0000-0000-000000000000');

    assert.equal(yanit.status, 404);
  });
});

describe('yetkisiz sohbet erisimi', () => {
  it('katilimci olmayan kullanici sohbeti hicbir sekilde goremez', async () => {
    const denemeler = [
      ['detay', istek(yabanci, 'get', `/conversations/${sohbetId}`)],
      ['mesajlar', istek(yabanci, 'get', `/conversations/${sohbetId}/messages`)],
      [
        'mesaj gonderme',
        istek(yabanci, 'post', `/conversations/${sohbetId}/messages`).send({ content: 'sizma' }),
      ],
      [
        'arsivleme',
        istek(yabanci, 'patch', `/conversations/${sohbetId}/archive`).send({ archived: true }),
      ],
    ];

    for (const [ad, sozu] of denemeler) {
      const yanit = await sozu;
      assert.equal(yanit.status, 404, `${ad} sizdirdi`);
    }
  });
});

describe('arsivleme ve sessize alma', () => {
  it('arsivlenen sohbet ana listeden cikar, arsiv listesinde gorunur', async () => {
    const arsivle = await istek(ben, 'patch', `/conversations/${sohbetId}/archive`).send({
      archived: true,
    });
    assert.equal(arsivle.status, 204);

    const ana = await istek(ben, 'get', '/conversations');
    const arsiv = await istek(ben, 'get', '/conversations?archived=true');

    assert.equal(
      ana.body.data.some((s) => s.id === sohbetId),
      false
    );
    assert.ok(arsiv.body.data.some((s) => s.id === sohbetId));

    await istek(ben, 'patch', `/conversations/${sohbetId}/archive`).send({ archived: false });
  });

  it('sessize alma detaya yansir, gecersiz tip reddedilir', async () => {
    const sessiz = await istek(ben, 'patch', `/conversations/${sohbetId}/mute`).send({ muted: true });
    assert.equal(sessiz.status, 204);

    const detay = await istek(ben, 'get', `/conversations/${sohbetId}`);
    assert.equal(detay.body.data.isMuted, true);

    const gecersiz = await istek(ben, 'patch', `/conversations/${sohbetId}/mute`).send({
      muted: 'evet',
    });
    assert.equal(gecersiz.status, 400);

    await istek(ben, 'patch', `/conversations/${sohbetId}/mute`).send({ muted: false });
  });
});

describe('ek gonderimi', () => {
  it('gorsel gonderilir, jpeg olarak saklanir ve indirilebilir', async () => {
    const yanit = await istek(ben, 'post', `/conversations/${sohbetId}/messages/image`).attach(
      'file',
      PNG,
      'test.png'
    );

    assert.equal(yanit.status, 201);
    assert.equal(yanit.body.data.type, 'IMAGE');

    const ek = yanit.body.data.attachments[0];
    // Goreli yol saklaniyor: sunucu adresi degisince eski mesajlarin eki bozulmasin
    assert.ok(ek.url.startsWith('/uploads/'), `beklenmeyen url: ${ek.url}`);
    assert.ok(ek.url.endsWith('.jpg'), 'gorsel jpeg olarak yeniden kodlanmali');
    assert.ok(ek.sizeBytes > 0);

    const indirme = await api().get(ek.url);
    assert.equal(indirme.status, 200);

    await fs.unlink(path.join(process.cwd(), ek.url.replace(/^\//, '')));
  });

  it('dosyasiz istek reddedilir', async () => {
    const yanit = await istek(ben, 'post', `/conversations/${sohbetId}/messages/image`);

    assert.equal(yanit.status, 400);
  });

  it('gorsel ucuna metin dosyasi kabul edilmez', async () => {
    const yanit = await istek(ben, 'post', `/conversations/${sohbetId}/messages/image`).attach(
      'file',
      Buffer.from('bu bir metin dosyasi'),
      'sahte.txt'
    );

    assert.equal(yanit.status, 400);
  });

  it('gecersiz sohbete yukleme diske oksuz dosya birakmaz', async () => {
    const klasor = path.join(process.cwd(), 'uploads', 'messages');
    const oncesi = await fs.readdir(klasor).catch(() => []);

    const yanit = await istek(
      ben,
      'post',
      '/conversations/00000000-0000-0000-0000-000000000000/messages/image'
    ).attach('file', PNG, 'test.png');

    const sonrasi = await fs.readdir(klasor).catch(() => []);

    assert.ok([400, 404].includes(yanit.status));
    assert.equal(sonrasi.length, oncesi.length, 'basarisiz yuklemeden dosya kalmis');
  });
});

// deletedAt bir bayrak degil, gecmis icin kesim noktasi: sohbeti silen taraf
// eski mesajlari kaybeder ama sohbet yeni mesajla geri gelir.
describe('sohbet silme kesim noktasi', () => {
  let a;
  let b;
  let silmeSohbeti;

  before(async () => {
    a = await kullaniciOlustur();
    b = await kullaniciOlustur();
    silmeSohbeti = await sohbetOlustur(a, b, 'eski mesaj 1');

    await api()
      .post(`${API}/conversations/${silmeSohbeti}/messages`)
      .set('Authorization', `Bearer ${b.token}`)
      .send({ content: 'eski mesaj 2' });
  });

  it('silen tarafta gecmis kaybolur, karsi tarafta durur', async () => {
    const silme = await istek(a, 'delete', `/conversations/${silmeSohbeti}`);
    assert.equal(silme.status, 204);

    const silen = await istek(a, 'get', `/conversations/${silmeSohbeti}/messages`);
    const karsiTaraf = await istek(b, 'get', `/conversations/${silmeSohbeti}/messages`);

    assert.equal(silen.body.data.items.length, 0);
    assert.equal(karsiTaraf.body.data.items.length, 2);

    const liste = await istek(a, 'get', '/conversations');
    assert.equal(
      liste.body.data.some((s) => s.id === silmeSohbeti),
      false
    );
  });

  it('yeni mesaj gelince sohbet yalnizca o mesajla geri doner', async () => {
    await api()
      .post(`${API}/conversations/${silmeSohbeti}/messages`)
      .set('Authorization', `Bearer ${b.token}`)
      .send({ content: 'silmeden sonraki' });

    const mesajlar = await istek(a, 'get', `/conversations/${silmeSohbeti}/messages`);
    const liste = await istek(a, 'get', '/conversations');

    assert.equal(mesajlar.body.data.items.length, 1);
    assert.equal(mesajlar.body.data.items[0].content, 'silmeden sonraki');
    assert.ok(liste.body.data.some((s) => s.id === silmeSohbeti));
  });
});
