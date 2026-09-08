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