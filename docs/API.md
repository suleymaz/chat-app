# API Dokümantasyonu

Temel adres: `http://<sunucu>:5000/api/v1`

Sunucu durumu için sürümsüz tek bir uç vardır: `GET /health`.

## İçindekiler

- [Yanıt biçimi](#yanıt-biçimi)
- [Kimlik doğrulama](#kimlik-doğrulama)
- [Hata kodları](#hata-kodları)
- [İstek sınırları](#istek-sınırları)
- [Uç noktalar](#uç-noktalar)
  - [/auth](#auth)
  - [/users](#users)
  - [/conversations](#conversations)
  - [/messages](#messages)
  - [/notifications](#notifications)
- [Socket.IO olayları](#socketio-olayları)

## Yanıt biçimi

Tüm yanıtlar aynı zarfı kullanır. Mobil tarafta tek bir ayrıştırma katmanı yazılabilsin
diye bu biçimden sapılmaz.

**Başarılı**

```json
{ "success": true, "data": { } }
```

**Hatalı**

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Şifre en az 8 karakter olmalı",
    "details": [{ "path": "body.password", "message": "Şifre en az 8 karakter olmalı" }]
  }
}
```

`details` yalnızca doğrulama hatalarında bulunur. `stack` alanı yalnızca
`NODE_ENV=development` iken ve yalnızca 5xx hatalarda eklenir.

**Sayfalanmış**

Mesaj listesi imleç (cursor) tabanlı sayfalama kullanır:

```json
{
  "success": true,
  "data": {
    "items": [],
    "nextCursor": "2026-09-20T18:44:03.120Z|9f1c...",
    "hasMore": true
  }
}
```

İmleç `<ISO tarih>|<mesaj id>` biçimindedir ve istemci için opak bir değerdir. Sıralama
yalnızca tarihe dayansaydı aynı milisaniyede oluşan iki mesaj sayfa sınırında
atlanabilirdi; id ikinci ölçüt olarak bu belirsizliği kaldırır.

Sohbet listesi (`GET /conversations`) sayfalanmaz, düz bir dizi döner.

## Kimlik doğrulama

İki aşamalı token kullanılır:

| Token | Süre | Saklanma |
|---|---|---|
| Access token | 15 dakika | Yalnızca istemcide, her istekte `Authorization` başlığında |
| Refresh token | 7 gün | Sunucuda SHA-256 özeti olarak (`RefreshToken.tokenHash`) |

```
Authorization: Bearer <accessToken>
```

Access token doğrulaması durumsuzdur, veritabanına gidilmez. Refresh token ise her
yenilemede döndürülür (rotation): eskisi iptal edilir, yenisi verilir.

**Yeniden kullanım tespiti.** İptal edilmiş bir refresh token ikinci kez kullanılırsa bu,
token'ın çalınmış olabileceğine işaret sayılır ve o kullanıcının tüm refresh token zinciri
iptal edilir. Yanıt `401 TOKEN_REUSE_DETECTED` olur ve kullanıcının yeniden giriş yapması
gerekir.

## Hata kodları

| Kod | HTTP | Anlamı |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Gönderilen veri şemaya uymuyor, `details` alanına bakın |
| `BAD_REQUEST` | 400 | Genel istemci hatası |
| `INVALID_JSON` | 400 | İstek gövdesi geçerli JSON değil |
| `PAYLOAD_TOO_LARGE` | 400 | Gövde 1 MB sınırını aşıyor |
| `INVALID_FILE_TYPE` | 400 | Dosya türü desteklenmiyor |
| `FILE_TOO_LARGE` | 400 | Dosya boyut sınırını aşıyor |
| `NO_FILE` | 400 | Çok parçalı istekte `file` alanı yok |
| `NO_RECIPIENT` | 400 | Çok parçalı istekte `userId` alanı yok |
| `UPLOAD_ERROR` | 400 | Yükleme sırasında başka bir hata |
| `SELF_CONVERSATION` | 400 | Kendisiyle sohbet açma denemesi |
| `SELF_MESSAGE` | 400 | Kendisine mesaj gönderme denemesi |
| `SELF_BLOCK` | 400 | Kendini engelleme denemesi |
| `UNAUTHORIZED` | 401 | Kimlik doğrulama gerekli |
| `NO_TOKEN` | 401 | `Authorization` başlığı yok |
| `INVALID_TOKEN` | 401 | Token çözülemedi veya imzası geçersiz |
| `TOKEN_EXPIRED` | 401 | Access token süresi dolmuş |
| `INVALID_CREDENTIALS` | 401 | Kullanıcı adı/şifre eşleşmiyor |
| `INVALID_CURRENT_PASSWORD` | 401 | Girilen mevcut şifre yanlış |
| `INVALID_REFRESH_TOKEN` | 401 | Refresh token bilinmiyor veya iptal edilmiş |
| `REFRESH_TOKEN_EXPIRED` | 401 | Refresh token süresi dolmuş |
| `TOKEN_REUSE_DETECTED` | 401 | Harcanmış token tekrar kullanıldı, zincir iptal edildi |
| `FORBIDDEN` | 403 | Kaynak var ama bu kullanıcının yetkisi yok |
| `NOT_MESSAGE_OWNER` | 403 | Başkasının mesajını silme denemesi |
| `NOT_FOUND` | 404 | Kayıt bulunamadı |
| `USER_NOT_FOUND` | 404 | Kullanıcı yok veya engel nedeniyle erişilemiyor |
| `CONVERSATION_NOT_FOUND` | 404 | Sohbet yok veya katılımcısı değilsiniz |
| `MESSAGE_NOT_FOUND` | 404 | Mesaj bulunamadı |
| `NOT_BLOCKED` | 404 | Engeli kaldırılmak istenen kullanıcı engelli değil |
| `NO_AVATAR` | 404 | Silinecek profil fotoğrafı yok |
| `USERNAME_TAKEN` | 409 | Kullanıcı adı başkasında |
| `EMAIL_TAKEN` | 409 | E-posta başkasında |
| `PHONE_TAKEN` | 409 | Telefon başkasında |
| `ALREADY_BLOCKED` | 409 | Kullanıcı zaten engellenmiş |
| `CONFLICT` | 409 | Genel çakışma |
| `DUPLICATE_FIELD` | 409 | Veritabanı benzersizlik kısıtı ihlali |
| `TOO_MANY_REQUESTS` | 429 | İstek sınırı aşıldı |
| `INTERNAL_ERROR` | 500 | Beklenmeyen sunucu hatası |

Yetkisiz erişimde çoğu yerde `403` yerine `404` döndürülür: katılımcısı olmadığınız bir
sohbetin varlığını öğrenmeniz bile bilgi sızıntısıdır.

## İstek sınırları

| Kapsam | Sınır |
|---|---|
| `/api/v1/*` | 15 dakikada 300 istek |
| `/auth/register`, `/auth/login` | 15 dakikada 10 başarısız istek |

Sınır IP tabanlıdır ve bellekte tutulur, sunucu yeniden başlayınca sıfırlanır. Giriş
sınırında başarılı istekler sayılmaz (`skipSuccessfulRequests`), böylece normal kullanan
biri kilitlenmez. `NODE_ENV=test` iken sınır devre dışıdır.

Kalan hak `RateLimit-Limit` ve `RateLimit-Remaining` başlıklarında döner.

---

## Uç noktalar

Aşağıdaki tabloda **Yetki** sütunu, uç noktanın geçerli bir access token gerektirip
gerektirmediğini gösterir.

### /auth

| Yöntem | Yol | Yetki | Açıklama |
|---|---|---|---|
| POST | `/auth/register` | — | Yeni kullanıcı oluşturur |
| POST | `/auth/login` | — | Kullanıcı adı, e-posta veya telefonla giriş |
| POST | `/auth/refresh` | — | Access token yeniler |
| POST | `/auth/logout` | isteğe bağlı | Refresh token'ı iptal eder |

#### POST /auth/register

```json
{
  "username": "ahmet",
  "email": "ahmet@example.com",
  "phone": "05551110001",
  "fullName": "Ahmet Yılmaz",
  "password": "Test1234!"
}
```

| Alan | Kural |
|---|---|
| `username` | 3-30 karakter, yalnızca küçük harf, rakam ve alt çizgi |
| `email` | Geçerli e-posta, küçük harfe çevrilir |
| `phone` | `05XXXXXXXXX` (11 hane). `+90...`, `90...` ve 10 haneli girdiler de kabul edilip bu biçime çevrilir |
| `fullName` | 2-100 karakter |
| `password` | 8-72 karakter, en az bir küçük harf, bir büyük harf ve bir rakam |

**201 Created**

```json
{
  "success": true,
  "data": {
    "user": { "id": "9f1c...", "username": "ahmet", "email": "ahmet@example.com",
              "phone": "05551110001", "fullName": "Ahmet Yılmaz", "avatarUrl": null },
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "eyJhbGciOi..."
  }
}
```

**409** `USERNAME_TAKEN` / `EMAIL_TAKEN` / `PHONE_TAKEN` · **400** `VALIDATION_ERROR`

#### POST /auth/login

```json
{ "identifier": "ahmet", "password": "Test1234!" }
```

`identifier` kullanıcı adı, e-posta veya telefon olabilir. Telefon girildiğinde kayıttaki
gibi normalleştirilir, yani `+905551110001` ve `05551110001` aynı hesabı bulur.

**200 OK** — gövde `register` ile aynıdır.

**401** `INVALID_CREDENTIALS`. Hata mesajı kullanıcının var olup olmadığını ayırt etmez;
aksi halde bu uç, kayıtlı kullanıcıları taramak için kullanılabilirdi.

#### POST /auth/refresh

```json
{ "refreshToken": "eyJhbGciOi..." }
```

**200 OK** — yeni `accessToken` **ve** yeni `refreshToken` döner. Eski refresh token
o anda iptal edilir.

**401** `INVALID_REFRESH_TOKEN` / `REFRESH_TOKEN_EXPIRED` / `TOKEN_REUSE_DETECTED`

#### POST /auth/logout

```json
{ "refreshToken": "eyJhbGciOi..." }
```

**204 No Content**

Access token süresi dolmuş kullanıcı da çıkış yapabilsin diye bu uçta giriş zorunlu
değildir. Token gönderilirse `lastSeenAt` da güncellenir.

---

### /users

Tümü giriş gerektirir.

| Yöntem | Yol | Açıklama |
|---|---|---|
| GET | `/users/me` | Kendi profilim |
| PATCH | `/users/me` | Profil güncelleme |
| PATCH | `/users/me/password` | Şifre değiştirme |
| GET | `/users/me/blocked` | Engellediğim kullanıcılar |
| POST | `/users/me/avatar` | Profil fotoğrafı yükleme (multipart) |
| DELETE | `/users/me/avatar` | Profil fotoğrafını kaldırma |
| GET | `/users/search?q=` | Kullanıcı arama |
| GET | `/users/:id` | Başka bir kullanıcının profili |
| POST | `/users/:id/block` | Kullanıcıyı engelleme |
| DELETE | `/users/:id/block` | Engeli kaldırma |

#### GET /users/me

**200 OK**

```json
{
  "success": true,
  "data": {
    "id": "9f1c...", "username": "ahmet", "email": "ahmet@example.com",
    "phone": "05551110001", "fullName": "Ahmet Yılmaz",
    "avatarUrl": "/uploads/avatars/1758...-a3f2.jpg",
    "bio": "Yazılım geliştirici",
    "isOnline": true, "lastSeenAt": "2026-09-21T18:44:03.120Z",
    "notificationsEnabled": true, "notificationPreview": "NAME_AND_MESSAGE"
  }
}
```

`avatarUrl` göreli bir yoldur. Tam adres istemcide sunucu kökü ile birleştirilir; böylece
sunucunun adresi değiştiğinde veritabanındaki kayıtlara dokunmak gerekmez.

#### PATCH /users/me

Gönderilen alanlar güncellenir, en az bir alan zorunludur.

```json
{ "fullName": "Ahmet Yılmaz", "bio": "Müsait değilim" }
```

| Alan | Kural |
|---|---|
| `fullName` | 2-100 karakter |
| `username` | Kayıttaki ile aynı kurallar |
| `email` | Geçerli e-posta |
| `phone` | `05XXXXXXXXX` |
| `bio` | En fazla 160 karakter, `null` gönderilebilir |
| `notificationsEnabled` | `true` / `false` |
| `notificationPreview` | `NAME_AND_MESSAGE` \| `NAME_ONLY` \| `NONE` |
| `currentPassword` | Kimlik alanları değişiyorsa zorunlu |

**`username`, `email` veya `phone` değiştiriliyorsa `currentPassword` zorunludur.**
Telefonunu bir başkasına ödünç veren kullanıcının hesabı, açık kalan bir oturum üzerinden
kullanıcı adı ve e-posta değiştirilerek tamamen devralınabilirdi.

**200 OK** güncel profil · **400** şifresiz kimlik değişikliği · **401** yanlış şifre ·
**409** `USERNAME_TAKEN` / `EMAIL_TAKEN` / `PHONE_TAKEN`

#### PATCH /users/me/password

```json
{ "currentPassword": "Test1234!", "newPassword": "YeniSifre1!" }
```

**204 No Content** · **401** yanlış mevcut şifre · **400** yeni şifre kurallara uymuyor

#### POST /users/me/avatar

`multipart/form-data`, alan adı `file`. JPEG, PNG, WEBP veya GIF; en fazla 5 MB.

Yüklenen görsel sunucuda yeniden boyutlandırılıp JPEG'e çevrilir ve önceki avatar
diskten silinir.

**200 OK** — güncel profil nesnesi döner (`GET /users/me` ile aynı biçimde), `avatarUrl`
alanı yeni dosyayı gösterir.

**400** `NO_FILE` / `INVALID_FILE_TYPE` / `FILE_TOO_LARGE`

#### DELETE /users/me/avatar

**200 OK** — `avatarUrl` alanı `null` olan güncel profil döner, dosya diskten silinir.

**404** `NO_AVATAR` — kaldırılacak fotoğraf yok

#### GET /users/search?q=ahmet&limit=20

`q` en az 2 karakter olmalıdır. Kullanıcı adı, ad soyad, e-posta ve telefon üzerinde arar.

Sonuçlarda arayan kullanıcının kendisi ve engellediği/onu engelleyen kullanıcılar yer
almaz. Dönen kayıtlarda e-posta ve telefon **bulunmaz** — arama ucu bir rehber dökümü
hâline gelmesin diye.

**200 OK**

```json
{
  "success": true,
  "data": [
    { "id": "9f1c...", "username": "ahmet", "fullName": "Ahmet Yılmaz",
      "avatarUrl": null, "isOnline": false, "lastSeenAt": "2026-09-21T10:00:00.000Z" }
  ]
}
```

**400** `q` iki karakterden kısa

#### GET /users/:id

**200 OK** — profil, iletişim bilgileriyle birlikte döner (sohbet ekranındaki kişi kartı
bunu kullanır).

**404** kullanıcı yok **veya** taraflardan biri diğerini engellemiş · **400** geçersiz UUID

#### POST /users/:id/block

**201 Created** · **409** zaten engellenmiş · **400** kendini engelleme denemesi

Engelleme tek yönlüdür ve karşı tarafa bildirilmez: engellenen kullanıcı mesaj
gönderdiğinde `201` alır, ancak mesaj karşı tarafa iletilmez ve bildirim gitmez.

#### DELETE /users/:id/block

**204 No Content** · **404** zaten engelli değil

---

### /conversations

Tümü giriş gerektirir.

| Yöntem | Yol | Açıklama |
|---|---|---|
| GET | `/conversations?archived=` | Sohbet listesi |
| POST | `/conversations/with-user` | Bir kullanıcıyla olan sohbeti bul/aç |
| GET | `/conversations/:id` | Sohbet detayı |
| DELETE | `/conversations/:id` | Sohbeti kendi tarafımdan sil |
| POST | `/conversations/:id/read` | Okundu işaretle |
| PATCH | `/conversations/:id/archive` | Arşivle / arşivden çıkar |
| PATCH | `/conversations/:id/mute` | Sessize al / sesi aç |
| GET | `/conversations/:id/messages` | Mesaj geçmişi (sayfalı) |
| POST | `/conversations/:id/messages` | Metin mesajı gönder |
| POST | `/conversations/:id/messages/image` | Görsel gönder (multipart) |
| POST | `/conversations/:id/messages/file` | Dosya gönder (multipart) |
| GET | `/conversations/:id/messages/search?q=` | Sohbet içinde ara |

#### GET /conversations

`?archived=true` arşivlenmişleri, parametresiz hâli normal listeyi döndürür. Son mesaja
göre yeniden eskiye sıralıdır.

**200 OK**

```json
{
  "success": true,
  "data": [
    {
      "id": "3b7e...",
      "user": { "id": "5d2a...", "username": "ayse", "fullName": "Ayşe Demir",
                "avatarUrl": null, "isOnline": true, "lastSeenAt": null },
      "lastMessage": {
        "id": "8c4f...", "senderId": "5d2a...", "content": "Yarın müsait misin?",
        "type": "TEXT", "deliveredAt": "2026-09-21T18:44:05.000Z", "readAt": null,
        "deletedAt": null, "createdAt": "2026-09-21T18:44:03.120Z", "attachments": []
      },
      "unreadCount": 1,
      "isMuted": false,
      "isArchived": false,
      "lastMessageAt": "2026-09-21T18:44:03.120Z"
    }
  ]
}
```

#### POST /conversations/with-user

```json
{ "userId": "5d2a..." }
```

**200 OK** — sohbet varsa:

```json
{ "success": true, "data": { "id": "3b7e...", "isNew": false, "user": { },
                             "lastMessageAt": "2026-09-21T18:44:03.120Z" } }
```

Sohbet henüz yoksa `id` alanı `null`, `isNew` alanı `true` döner ve **veritabanına kayıt
yazılmaz**:

```json
{ "success": true, "data": { "id": null, "isNew": true, "user": { },
                             "lastMessageAt": null } }
```

Sohbet ilk mesaj gönderildiğinde oluşturulur, böylece hiç mesajlaşılmamış boş kayıtlar
birikmez.

**400** `SELF_CONVERSATION` · **404** `USER_NOT_FOUND` (kullanıcı yok veya engel var)

#### GET /conversations/:id

**200 OK**

```json
{
  "success": true,
  "data": {
    "id": "3b7e...", "user": { }, "isBlocked": false, "isMuted": false,
    "isArchived": false, "lastReadAt": "2026-09-21T18:40:00.000Z"
  }
}
```

`isBlocked`, **bu kullanıcının** karşı tarafı engelleyip engellemediğini söyler; karşı
tarafın engeli bu alana yansımaz, aksi hâlde engellendiğiniz karşı tarafa belli olurdu.

**404** sohbet yok veya katılımcısı değilsiniz

#### DELETE /conversations/:id

**204 No Content**

Silme yalnızca isteği yapan tarafı etkiler ve bir bayrak değil, **kesim noktası**dır:
`deletedAt` damgalanır, o tarihten eski mesajlar artık bu kullanıcıya gösterilmez, karşı
tarafta ise geçmiş olduğu gibi durur. Yeni bir mesaj geldiğinde sohbet listeye geri döner
ve yalnızca yeni mesajları içerir.

#### POST /conversations/:id/read

**204 No Content** — katılımcının `lastReadAt` değeri güncellenir, karşı tarafa
`message:read` olayı gönderilir.

#### PATCH /conversations/:id/archive · /mute

```json
{ "archived": true }
```

```json
{ "muted": true }
```

**204 No Content** · **400** alan boolean değil · **404** katılımcı değilsiniz

Sessize alınan sohbette mesaj normal şekilde gelir, yalnızca FCM bildirimi gönderilmez.

#### GET /conversations/:id/messages?cursor=&limit=30

En yeniden eskiye sıralıdır; `limit` varsayılanı 30, en fazla 100.

**200 OK**

```json
{
  "success": true,
  "data": {
    "items": [
      { "id": "8c4f...", "conversationId": "3b7e...", "senderId": "5d2a...",
        "content": "Yarın müsait misin?", "type": "TEXT",
        "deliveredAt": "2026-09-21T18:44:05.000Z", "readAt": null, "deletedAt": null,
        "createdAt": "2026-09-21T18:44:03.120Z", "attachments": [] }
    ],
    "nextCursor": "2026-09-21T18:44:03.120Z|8c4f...",
    "hasMore": true
  }
}
```

Silinmiş mesajlarda `content` alanı `null` döner — içerik istemcide gizlenmez, sunucudan
hiç gönderilmez.

#### POST /conversations/:id/messages

```json
{ "content": "Merhaba" }
```

`content` kırpıldıktan sonra 1-4000 karakter olmalıdır; yalnızca boşluktan oluşan mesaj
reddedilir.

**201 Created** — oluşturulan mesaj nesnesi döner.

#### POST /conversations/:id/messages/image · /file

`multipart/form-data`, alan adı `file`.

| Uç | İzinli türler | Sınır |
|---|---|---|
| `/image` | JPEG, PNG, WEBP, GIF | 5 MB |
| `/file` | Yukarıdakiler + PDF, Word, Excel, PowerPoint, TXT, CSV, ZIP, RAR | 20 MB |

Görseller sunucuda yeniden boyutlandırılıp JPEG'e çevrilir. Dosyalarda özgün ad
`Attachment.fileName` alanında saklanır, diske ise tahmin edilemez rastgele bir adla
yazılır (yol aşımı ve ad çakışması riski).

**201 Created**

```json
{
  "success": true,
  "data": {
    "id": "8c4f...", "type": "IMAGE", "content": null,
    "attachments": [{ "id": "1a2b...", "url": "/uploads/messages/1758...-9d3e.jpg",
                      "fileName": null, "mimeType": "image/jpeg",
                      "sizeBytes": 84213, "width": 1080, "height": 1440 }]
  }
}
```

**400** `NO_FILE` / `INVALID_FILE_TYPE` / `FILE_TOO_LARGE`

#### GET /conversations/:id/messages/search?q=proje&limit=20

`q` en az 2 karakter. Yalnızca o sohbetteki, silinmemiş ve kesim noktasından yeni
mesajlarda arar.

**200 OK** — mesaj dizisi (sayfalanmaz).

---

### /messages

Sohbet henüz yokken ilk mesajı göndermek ve mesaj silmek için kullanılır. Tümü giriş
gerektirir.

| Yöntem | Yol | Açıklama |
|---|---|---|
| POST | `/messages` | Yeni sohbet başlatıp ilk metin mesajını gönder |
| POST | `/messages/image` | Yeni sohbette ilk mesaj olarak görsel |
| POST | `/messages/file` | Yeni sohbette ilk mesaj olarak dosya |
| DELETE | `/messages/:id` | Kendi mesajını sil |

#### POST /messages

```json
{ "userId": "5d2a...", "content": "Merhaba" }
```

Sohbet yoksa oluşturulur. Sohbet oluşturma, iki katılımcı kaydı ve mesaj ekleme tek bir
transaction içinde yapılır; aksi hâlde yarıda kalan bir istek katılımcısız sohbet
bırakabilirdi.

**201 Created** — mesaj nesnesi, `conversationId` alanıyla birlikte.

#### POST /messages/image · /messages/file

`multipart/form-data`: `file` alanı ve `userId` alanı. Sınırlar sohbet içi uçlarla aynıdır.

#### DELETE /messages/:id

**200 OK**

```json
{ "success": true, "data": { "id": "8c4f...", "content": null,
                             "deletedAt": "2026-09-21T19:02:11.400Z" } }
```

Kayıt silinmez, `deletedAt` damgalanır ve `content` temizlenir; sohbette yerinde
"Bu mesaj silindi" gösterilebilsin diye.

**403** başkasının mesajı · **404** mesaj yok

---

### /notifications

Tümü giriş gerektirir.

| Yöntem | Yol | Açıklama |
|---|---|---|
| POST | `/notifications/token` | Cihazın FCM token'ını kaydet |
| DELETE | `/notifications/token` | Token kaydını sil (çıkışta) |

#### POST /notifications/token

```json
{ "fcmToken": "dXNlcl9...", "platform": "android" }
```

**201 Created**

Aynı token başka bir hesapta kayıtlıysa yeni kullanıcıya taşınır — ortak kullanılan bir
cihazda bildirimlerin önceki hesaba gitmeye devam etmemesi için.

#### DELETE /notifications/token

```json
{ "fcmToken": "dXNlcl9..." }
```

**204 No Content**

---

## Socket.IO olayları

Bağlantı adresi REST ile aynı sunucudur. Token el sıkışma (handshake) sırasında
gönderilir:

```js
io('http://<sunucu>:5000', {
  auth: { token: accessToken },
  transports: ['websocket'],
});
```

Token yoksa veya geçersizse bağlantı reddedilir. Kimlik bir kez doğrulanır, bağlantı
kurulduktan sonra tekrar sorgulanmaz.

**İstemciden sunucuya**

| Olay | Veri | Açıklama |
|---|---|---|
| `conversation:join` | `{ conversationId }` | Sohbet odasına katılır. Katılımcı değilseniz istek sessizce yok sayılır |
| `conversation:leave` | `{ conversationId }` | Odadan ayrılır |
| `typing:start` | `{ conversationId }` | Yazıyor göstergesini açar |
| `typing:stop` | `{ conversationId }` | Yazıyor göstergesini kapatır |

**Sunucudan istemciye**

| Olay | Veri | Ne zaman |
|---|---|---|
| `message:new` | Mesaj nesnesi | Size bir mesaj gönderildiğinde |
| `message:delivered` | `{ conversationId, messageIds, deliveredAt }` | Gönderdiğiniz mesaj karşı tarafa ulaştığında |
| `message:read` | `{ conversationId, readAt }` | Karşı taraf sohbeti okuduğunda |
| `message:deleted` | `{ conversationId, messageId }` | Karşı taraf mesajını sildiğinde |
| `user:online` | `{ userId }` | Bir kullanıcı çevrimiçi olduğunda |
| `user:offline` | `{ userId, lastSeenAt }` | Bir kullanıcının son bağlantısı koptuğunda |

Mesaj gönderme socket üzerinden **yapılmaz**, REST ile yapılır. Socket yalnızca iletim
kanalıdır. Böylece doğrulama, hata yönetimi ve HTTP durum kodları tek yerde kalır ve
socket bağlantısı kopmuş olsa bile mesaj gönderilebilir.

Çevrimiçi durumu bağlantı sayacıyla tutulur: aynı kullanıcı iki cihazdan bağlıysa biri
kapandığında hâlâ çevrimiçi sayılır, sayaç sıfıra inince `user:offline` yayınlanır.
