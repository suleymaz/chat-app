# Teknik Kararlar

## Gün 1 — Veri Modeli

**PostgreSQL seçildi.**
Veri modeli baştan sona ilişkisel (User, Conversation, Message arasında net foreign key
ilişkileri var). Transaction desteği, mesaj gönderiminde sohbet oluşturma + mesaj ekleme
işlemlerinin atomik yapılmasını sağlıyor. Full-text search desteği mesaj arama özelliği
için kullanılacak.

**ORM olarak Prisma kullanıldı.**
Şema tek dosyada tanımlanıyor, migration'lar versiyonlanıyor ve ER diyagramı şemadan
üretilebiliyor.

**ConversationParticipant ara tablosu kullanıldı (user1Id/user2Id yerine).**
Arşivleme, susturma ve okundu bilgisi sohbete değil, kullanıcı-sohbet ilişkisine ait.
user1Id/user2Id yaklaşımında bu bilgiler için kullanıcı başına ayrı kolon açmak ve kodda
sürekli "bu kullanıcı user1 mi user2 mi" kontrolü yapmak gerekirdi. Ara tablo ayrıca
sorguyu basitleştiriyor (OR yerine tek kolonda eşitlik) ve grup desteğine açık bırakıyor.

**Message tablosunda receiverId tutulmadı.**
Alıcı, conversationId üzerinden katılımcılardan çıkarılabiliyor. Ayrıca tutmak veri
tekrarı olur ve iki kaynak çeliştiğinde tutarsızlık riski doğurur.

**Mesaj durumu ayrı tablo yerine deliveredAt/readAt timestamp'leri ile tutuldu.**
Birebir sohbette her mesajın tek alıcısı var, bu yüzden MessageStatus tablosu Message ile
birebir ilişki oluşturur ve her sorguya gereksiz JOIN ekler. Timestamp yaklaşımı hem
durumu hem zaman bilgisini tek satırda taşıyor. Grup desteği eklenirse ayrı tabloya
geçilmesi gerekir.

**Sohbet, ilk mesaj gönderildiğinde oluşturuluyor.**
Kullanıcı bir profili açtığında sohbet oluşturulsaydı, hiç mesajlaşılmayan boş kayıtlar
birikirdi. Oluşturma işlemi transaction içinde yapılacak (Conversation + iki
ConversationParticipant + Message).

**Mesaj silme soft delete ile yapılıyor (deletedAt).**
Silinen mesajın yerinde "Bu mesaj silindi" gösterilebilmesi için kaydın kalması gerekiyor.
API yanıtında deletedAt doluysa content alanı hiç gönderilmiyor.

**UUID birincil anahtar olarak seçildi.**
Artan integer ID'ler tahmin edilebilir olduğu için IDOR riskine açık. UUID ayrıca istemci
tarafında üretilebildiği için optimistic UI'yi mümkün kılıyor.

**Bildirim içeriği maskeleme sunucu tarafında yapılıyor.**
notificationPreview ayarı NAME_ONLY veya NONE ise mesaj içeriği FCM'e hiç gönderilmiyor.
İçeriği gönderip istemcide gizlemek sahte bir gizlilik olurdu.

**Kapsam dışı bırakılanlar:** Grup sohbeti, sesli/görüntülü arama, uçtan uca şifreleme,
"benden sil" seçeneği. Veri modeli grup desteğine açık tasarlandı.

## Gün 2 — Backend Mimarisi

**Katmanlı mimari kuruldu: routes → controllers → services → repositories.**
Her katmanın tek sorumluluğu var. Service katmanı HTTP'den bağımsız tutuldu (req/res
almıyor), böylece mesaj gönderme gibi iş mantıkları hem REST endpoint'inden hem Socket.IO
handler'ından aynı kaynaktan çağrılabilecek.

**Ortam değişkenleri Zod ile başlangıçta doğrulanıyor (config/env.js).**
Eksik veya hatalı .env durumunda uygulama açık bir mesajla başlangıçta duruyor. Aksi
halde hata, çalışma zamanında anlaşılmaz bir undefined olarak ortaya çıkardı.

**Tek PrismaClient örneği kullanılıyor (config/database.js).**
Her dosyada new PrismaClient() oluşturmak bağlantı havuzunu tüketiyor.

**Merkezi hata yönetimi (middlewares/errorHandler.js).**
Prisma hataları (P2002, P2025, P2003) kullanıcı dostu mesajlara çevriliyor; ham hata
mesajları veritabanı yapısını ele verdiği için doğrudan döndürülmüyor. ApiError sınıfı
dışındaki beklenmeyen hatalar loglanıp istemciye genel bir "sunucu hatası" olarak
dönüyor. Stack trace yalnızca development ortamında yanıta ekleniyor.

**Standart yanıt formatı.**
Başarı: { success: true, data }, hata: { success: false, error: { code, message } }.
Flutter tarafında tek bir parse katmanı yazılabilmesi için.

**app.js ve server.js ayrıldı.**
Jest testlerinde app doğrudan import edilip gerçek port dinlemeden test edilebilsin diye.

**API sürümleme: /api/v1 öneki.**
/api öneki API yollarını statik dosya servisinden (/uploads) ayırıyor. v1 ise mobil
istemcilerin anında güncellenememesi nedeniyle ileride kırıcı değişiklik gerektiğinde
eski sürümü çalışır tutabilmek için eklendi.

**console.log yerine Winston logger.**
Seviye ayrımı (debug/info/warn/error), zaman damgası ve dosyaya yazma için.


## Gün 3 — Kimlik Doğrulama

**Access token (15dk) ve refresh token (7 gün) ayrımı.**
Access token her istekte kullanıldığı için stateless doğrulanıyor — veritabanına gidilmiyor,
bu yüzden iptal edilemiyor. Kısa ömür, çalınma durumunda hasarı sınırlıyor. Refresh token
ise veritabanında tutulduğu için iptal edilebiliyor; uzun ömrü kullanıcının sürekli giriş
yapmasını engelliyor.

**Refresh token rotation.**
Her yenilemede eski token iptal edilip yenisi veriliyor.

**Reuse detection.**
İptal edilmiş bir refresh token tekrar kullanılırsa, token'ın sızdığı varsayılıp o
kullanıcının tüm refresh token'ları iptal ediliyor. Hangi tarafın saldırgan olduğu
bilinemediği için zincirin tamamı kesiliyor; kullanıcı yeniden giriş yapıyor.

**Refresh token'lar veritabanında hash'lenerek saklanıyor (SHA-256).**
Veritabanı sızıntısında token'ların doğrudan kullanılabilir olmaması için. Parolada bcrypt
kullanılırken burada SHA-256 tercih edildi: token zaten yüksek entropili ve rastgele,
bcrypt'in kasıtlı yavaşlığına ihtiyaç yok.

**Login hataları ayrıştırılmıyor.**
Kullanıcı bulunamadığında da parola hatalı olduğunda da aynı mesaj dönüyor
(INVALID_CREDENTIALS). Farklı mesajlar, sistemde hangi e-postaların kayıtlı olduğunu
öğrenmeye (user enumeration) izin verirdi.

**Rate limiting auth endpoint'lerinde uygulanıyor.**
15 dakikada 10 istek. skipSuccessfulRequests: true ile yalnızca başarısız denemeler
sayılıyor, normal kullanıcı etkilenmiyor.

**Parola politikası: min 8 karakter, büyük/küçük harf ve rakam zorunlu.**
Üst sınır 72 karakter — bcrypt bundan uzun girdileri sessizce kesiyor.

**Kullanıcı yanıtlarında publicUserSelect kullanılıyor.**
Prisma varsayılan olarak tüm kolonları döndürdüğü için passwordHash'in yanıta sızmaması
adına tek bir select nesnesi tanımlandı.

**girisKontrol middleware'i her istekte veritabanına gidiyor.**
Token'daki sub alanı kullanıcı ID'sini zaten taşıyor, ancak silinmiş kullanıcıların
tespiti ve req.user içinde güncel profil bilgisine (isOnline, notificationPreview)
erişim için sorgu yapılıyor. JWT'nin stateless avantajından kısmen vazgeçilen bilinçli
bir takas.

**TOKEN_EXPIRED ve INVALID_TOKEN ayrı kodlar döndürüyor.**
Flutter tarafındaki interceptor TOKEN_EXPIRED durumunda sessizce refresh yapıp isteği
tekrarlayacak; INVALID_TOKEN durumunda kullanıcıyı giriş ekranına yönlendirecek. Ayrım
yapılmasaydı bozuk bir token sonsuz refresh döngüsüne yol açabilirdi.


## Gün 4 — Kullanıcı İşlemleri

**Başkasının profilinde e-posta ve telefon gizleniyor.**
Kendi profilinde (publicUserSelect) dönen bu alanlar, başkasının profilinde
(findProfileById) dönmüyor. Arama kriteri olmalarıyla çelişmiyor: kullanıcıyı e-postasıyla
arayabilirsin ama sonuçta e-postasını göremezsin.

**Arama davranışı alan bazında farklı.**
username ve fullName için kısmi eşleşme (contains), email ve phone için tam eşleşme
(equals). Kısmi e-posta araması, sistemdeki adresleri parça parça keşfetmeye izin verirdi.

**Engelleme çift yönlü etki gösteriyor.**
Ali Ayşe'yi engellediyse, Ayşe de Ali'yi arama sonuçlarında göremiyor ve profiline
erişemiyor. Tek yönlü olsaydı engellenen kişi engelleyeni izlemeye devam ederdi.

**Engellenen kullanıcının profili 404 dönüyor, 403 değil.**
"Bu kullanıcı sizi engelledi" mesajı vermek, engellenme bilgisini karşı tarafa açık
ederdi. Kullanıcı hiç yokmuş gibi davranılıyor.

**Şifre değişiminde tüm refresh token'lar iptal ediliyor.**
Şifre değiştirme genellikle bir güvenlik endişesinden kaynaklandığı için, başka
cihazlarda açık kalmış oturumların devam etmemesi gerekiyor.

**E-posta ve telefon güncellemesi kapsam dışı.**
Bu alanlar kimlik doğrulama kimliği olduğu için değiştirilmeleri doğrulama akışı
(e-postaya/SMS'e kod gönderme) gerektirir. Proje kapsamında bu akış geliştirilmedi.

**Route sıralaması: /me/blocked ve /search, /:id'den önce tanımlandı.**
Express route'ları sırayla eşleştirdiği için, /:id önce gelseydi "search" bir id olarak
yorumlanırdı.


## Gün 5 — Sohbetler ve Mesajlar
Sohbet listesini çekerken N+1 problemine düşmemek için Prisma'nın include özelliğini
kullandım. Her sohbetin son mesajını `take: 1` ile aynı sorguda alıyorum. Okunmamış sayısı
için ayrı sorgu atmak zorunda kaldım çünkü Prisma'nın _count özelliği "şu tarihten sonrası"
gibi koşullu sayımı desteklemiyor. Bunları Promise.all ile paralel çalıştırdım.

Mesaj listesinde offset yerine cursor pagination kullandım. Offset ile sayfa çekerken yeni
mesaj gelirse tüm kayıtlar kayıyor ve aynı mesajı iki kez görebiliyorsun. Cursor'da
referans noktası sabit olduğu için bu olmuyor. Cursor olarak createdAt kullandım.

hasMore bilgisini doğru vermek için limitten bir fazla kayıt çekiyorum. Önce "gelen sayı
limite eşitse devamı var" diye yazmıştım ama son sayfada tam limit kadar kayıt olduğunda
yanlış sonuç veriyordu — kullanıcı boşuna bir istek daha atıyordu.

Mesaj gönderirken sohbet oluşturma, mesaj ekleme ve lastMessageAt güncelleme işlemlerini
transaction içine aldım. Ortada birinde hata olursa yarım kayıt kalmasın diye.

Engelli kullanıcıya mesaj gönderildiğinde mesajı veritabanına yazmıyorum ama gönderene
başarılı yanıt dönüyorum. Kaydetseydim engel kalktığında eski mesajlar birden ortaya
çıkardı. Karşı tarafa engellendiği bilgisini vermemek için de hata dönmüyorum.

Sohbet silme kişiye özel — ConversationParticipant.deletedAt dolduruluyor, sohbetin
kendisi silinmiyor. Karşı taraf sohbeti görmeye devam ediyor. Arşivleme de aynı mantıkta.

Mesaj silmede önce sahiplik kontrolü yapıyorum (403), sohbete erişim kontrolünü sonra.
Sahiplik kontrolü daha ucuz olduğu için önce o çalışsın istedim. Burada 404 yerine 403
döndüm çünkü kullanıcı mesajı zaten görebiliyor, varlığını gizlemenin anlamı yok.

Express 4'te req.query salt okunur olduğu için Zod'un dönüştürdüğü değerler kullanılmıyordu
— limit parametresi string olarak gidiyor ve Prisma hata veriyordu. Doğrulanmış query
değerlerini req.validatedQuery içinde tutup controller'da oradan okuyacak şekilde
düzelttim.


## Gün 6 — Socket.IO

Socket auth'u handshake sırasında yapıyorum. Bağlantı kurulurken token geliyor, doğrulanıyor
ve socket nesnesine userId yazılıyor. Bağlantı kurulduktan sonra kimlik bir daha
sorgulanmıyor.

İki tür room kullandım. user:<userId> odasına kullanıcı bağlandığında otomatik katılıyor —
birden fazla cihazdan bağlanmış olabileceği için tek bir socket'e değil odaya yayın yapmak
gerekiyor. conversation:<id> odasına ise sohbet ekranı açıkken katılıyor, "yazıyor"
göstergesi gibi sadece o ekranda anlamlı olan event'ler için.

Mesaj gönderme işlemini socket üzerinden değil REST ile yapıyorum. Socket sadece mesajı
karşı tarafa iletmek için kullanılıyor. Böylece validation, hata yönetimi ve HTTP status
kodları tek yerde kalıyor; socket bağlantısı kopmuş olsa bile mesaj gönderilebiliyor.

Çevrimiçi durumu için bağlantı sayacı tuttum. Kullanıcı iki cihazdan bağlıysa sayaç 2
oluyor, biri kapanınca 1'e düşüyor ama kullanıcı hâlâ çevrimiçi sayılıyor. Sayaç sıfıra
inince offline yapılıyor ve lastSeenAt güncelleniyor.

kullaniciBagliMi fonksiyonu iki işe yarıyor: alıcı bağlıysa mesaj hemen "iletildi" olarak
işaretleniyor, ayrıca FCM bildirimi gönderilip gönderilmeyeceğine bu bilgiye göre karar
verilecek.

Test için basit bir HTML sayfası yazdım (socket-test.html). Postman socket testine uygun
olmadığı için iki tarayıcı sekmesinde iki kullanıcıyla bağlanıp event akışını izledim.

## Gün 7 — Dosya Yükleme ve Bildirimler

Dosyaları sunucu diskinde tutuyorum, uploads/ klasöründe. S3 gibi bir nesne deposu daha
doğru olurdu ama hesap ve API anahtarı gerektirdiği için projeyi klonlayan biri
çalıştıramazdı. Üretimde buranın değişmesi gerekir. file.service.js'i bir soyutlama
katmanı olarak yazdım, depolama stratejisi değişirse sadece o dosyaya dokunmak yeterli.

Yüklenen dosyanın orijinal adını kullanmıyorum. Zaman damgası + rastgele hex ile yeni ad
üretiyorum — hem çakışma olmuyor hem de "../../" gibi bir adla dosya sistemine sızma
riski kalmıyor. Dosya eklerinde orijinal adı Attachment.fileName alanında saklıyorum,
kullanıcı dosyayı kendi adıyla görsün diye.

Görselleri sharp ile yeniden boyutlandırıp sıkıştırıyorum. Avatar için 512px, mesaj
görselleri için 1280px. rotate() çağrısı önemli: telefonla çekilen fotoğraflarda EXIF
yönlendirme bilgisi oluyor, uygulanmazsa görsel yan yatıyor.

Dosya eklerini de kapsama aldım. Doküman 8. maddede "Dosya ve Görsel Gönderimi" diyor;
örnekler görsel üzerine ama başlık ikisini de kapsıyor. MessageType enum'una FILE ekledim.
Görsel ve dosya için ayrı boyut limiti var: görselde 5 MB, dosyada 20 MB. Görseller zaten
sıkıştırıldığı için 5 MB yeterli, dosyalarda sıkıştırma yapılmıyor.

Dosya yükleme endpoint'lerini /files altında toplamak yerine ilgili kaynağın altına koydum
(/users/me/avatar, /conversations/:id/messages/image, /conversations/:id/messages/file).
Böylece dosya bağlamsız yüklenip sonra ilişkilendirilmiyor, doğrudan ait olduğu yere
gidiyor.

Firebase'i opsiyonel yaptım. serviceAccountKey.json yoksa bildirimler devre dışı kalıyor
ama uygulama normal çalışıyor. Böylece Firebase hesabı olmayan biri de projeyi
çalıştırabiliyor. Veritabanı olmadan uygulama çalışamaz, orada çökmek doğru — ama bildirim
gönderememek mesajlaşmayı engellemiyor.

Bildirim gönderilip gönderilmeyeceğine socket bağlantı durumuna bakarak karar veriyorum.
Kullanıcı bağlıysa mesajı zaten görüyor, bildirim göndermek gereksiz. Bağlı değilse FCM
devreye giriyor.

Bildirim içeriği maskeleme sunucu tarafında yapılıyor. notificationPreview ayarı NONE veya
NAME_ONLY ise mesaj içeriği FCM'e hiç gönderilmiyor. İçeriği gönderip istemcide gizlemek
sahte bir gizlilik olurdu — veri zaten Google'ın sunucularından geçmiş olurdu.

Geçersiz FCM token'ları her gönderimde tespit edip siliyorum. Kullanıcı uygulamayı
silince token geçersiz oluyor, temizlenmezse tablo şişerdi.

helmet'in crossOriginResourcePolicy ayarını cross-origin yaptım. Varsayılan ayar
yüklenen görsellerin başka bir origin'den (Flutter uygulaması) yüklenmesini engelliyordu.

app.js'de statik dosya servisini notFoundHandler'dan sonra tanımlamıştım, /uploads
istekleri 404 dönüyordu. Middleware sırası önemli — 404 ve hata yakalayıcılar her zaman
en sonda olmalı.

Attachment tablosuna fileName eklerken şemayı kaydetmeden migration çalıştırmışım,
"Already in sync" dedi ama Prisma Client alanı tanımıyordu. Şemayı kaydedip tekrar
çalıştırınca düzeldi.


## Gün 8 — Flutter Kurulumu

State management için Riverpod seçtim. Provider'a göre derleme zamanında daha fazla hata
yakalıyor ve BuildContext gerektirmiyor. Bloc daha yapılandırılmış ama bu ölçekte fazla
boilerplate getiriyordu.

Routing için go_router kullandım. Asıl sebebi redirect özelliği: auth guard'ı tek yerden
yönetebiliyorum, her ekranda ayrı ayrı "giriş yapılmış mı" kontrolü yazmaya gerek kalmıyor.

API adresini String.fromEnvironment ile yapılandırılabilir bıraktım. Build sırasında
--dart-define=API_URL=... ile değiştirilebiliyor. Emülatörde 10.0.2.2, fiziksel cihazda
bilgisayarın yerel IP'si gerekiyor; deploy edilirse de aynı yerden değişecek.

Dio interceptor'ında token yenileme kuyruğu kurdum. Access token süresi dolunca 401
geliyor, interceptor bunu yakalayıp refresh yapıyor ve isteği tekrarlıyor — kullanıcı
hiçbir şey görmüyor. Kritik nokta şu: paralel beş istek aynı anda 401 alırsa beş ayrı
refresh gitmemeli, çünkü backend'de rotation var ve ilki diğerlerini geçersiz kılardı.
Bir bayrakla ilk refresh'i işaretleyip kalanları kuyruğa alıyorum.

Refresh isteği için ayrı bir Dio örneği kullanıyorum. Aynı örneği kullansaydım interceptor
tekrar devreye girip sonsuz döngü olurdu.

validateStatus'u 500'ün altını geçirecek şekilde ayarladım. Böylece 4xx yanıtlarını
onResponse içinde yakalayıp kendi ApiException tipime çevirebiliyorum.

Backend'in details dizisini alanHatalari haritasına çeviriyorum, form alanlarının altına
hata yazarken kullanacağım.

Derleme sırasında üç sorunla uğraştım: NDK eksikti (Android Studio SDK Manager'dan
kurdum), flutter_local_notifications core library desugaring istedi (build.gradle.kts'e
ekledim), ve file_picker eski compileSdk ile geliyordu. Sonuncusu için android/
build.gradle.kts içinde tüm alt projelerin compileSdk'sını 36'ya sabitleyen bir subprojects
bloğu yazdım. Bu bloğu evaluationDependsOn satırından önce koymak gerekiyor, sonra
koyduğumda "project is already evaluated" hatası verdi.

## Gün 9 — Giriş ve Kayıt Ekranları

Form doğrulamasını iki katmanlı yaptım. İstemci tarafında anında uyarı veriyorum —
kullanıcı sunucuya gitmeden hatayı görüyor. Sunucu tarafı yine de gerekli çünkü istemci
doğrulaması atlanabilir, ayrıca "bu kullanıcı adı alınmış" bilgisini sadece sunucu bilir.

Backend'in döndüğü alan bazlı hataları ilgili input'un altında gösteriyorum. VALIDATION_ERROR
durumunda details dizisi geliyor, USERNAME_TAKEN gibi durumlarda ise hata kodundan hangi
alan olduğunu çıkarıyorum.

Bir noktada takıldım: interceptor hatayı DioException içine sarıp ApiException'ı error
alanına koyuyor. Ekranda "on ApiException catch" yazınca yakalanmıyordu, hep genel hata
mesajı çıkıyordu. "on DioException catch" yapıp e.error'ı kontrol ederek çözdüm. Daha temiz
çözüm interceptor'ın doğrudan ApiException fırlatması olurdu, sonra bakacağım.

Ortak widget'lar yazdım (AppTextField, AppButton, HataKutusu) — her formda aynı stili
tekrar yazmamak için. AppTextField şifre alanlarında göster/gizle butonunu kendi içinde
hallediyor.


## Gün 10 — Sohbet Listesi ve Arama

Sohbet listesini ekran içinde setState ile tutmak yerine Riverpod provider'ına aldım.
Sebebi: liste üç yerden değişecek — ilk yükleme, pull-to-refresh, ve yarın ekleyeceğim
socket olayları. Socket katmanının ekranın state'ine erişmesi mümkün olmazdı.

AsyncValue kullanıyorum, loading/data/error üçünü tek tipte taşıyor. Ekranda when ile
üçünü de ele alabiliyorum, doküman 10. maddede istenen durumlar bunlar.

yukle() ve tazele() diye iki ayrı metot yazdım. İlki loading durumuna geçiyor ve ekranı
boşaltıyor, ikincisi mevcut listeyi ekranda tutup arka planda güncelliyor. Pull-to-refresh'te
listenin kaybolup geri gelmesi kötü görünürdü.

Aramada debounce var, 400ms. Kullanıcı "ahmet" yazarken her harfte istek atmıyorum, yazmayı
bıraktıktan sonra tek istek gidiyor.

Avatar rengini baş harflerden üretiyorum. Rastgele olsa aynı kişi her açılışta farklı renkte
görünürdü.

Boş liste durumunda RefreshIndicator'ın çalışması için Stack içine boş bir ListView koymak
gerekiyor. Kaydırılabilir alan olmadan pull-to-refresh tetiklenmiyor.