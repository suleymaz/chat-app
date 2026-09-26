import '../storage/secure_storage.dart';

class AppConfig {
  /// Derleme anında verilen varsayılan adres.
  /// `--dart-define=API_URL=...` ile değiştirilebilir.
  static const String _derlemeApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  static const String _socketUrlTanimi = String.fromEnvironment('SOCKET_URL');

  /// Uygulama içinden ayarlanan sunucu kökü (`http://adres:port`).
  ///
  /// Adres yalnızca derlemeye gömülseydi, teslim edilen APK derleyenin yerel
  /// IP'sine bağlı kalırdı: ağ değiştiğinde ya da uygulamayı başka biri
  /// çalıştırdığında yeniden derlemek gerekirdi. Bu yüzden adres cihazda
  /// saklanıyor ve giriş ekranından değiştirilebiliyor.
  static String? _ayarlananKok;

  static String get _derlemeKoku =>
      _derlemeApiUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');

  /// Sunucu kökü: görsel ve dosya adreslerinin birleştirildiği taban.
  static String get sunucuKoku => _ayarlananKok ?? _derlemeKoku;

  static String get apiUrl =>
      _ayarlananKok == null ? _derlemeApiUrl : '$_ayarlananKok/api/v1';

  /// Socket adresi. Kullanıcı bir adres ayarladıysa o kazanır; yoksa
  /// SOCKET_URL tanımı, o da yoksa API adresinden türetilen kök kullanılır.
  static String get socketUrl {
    if (_ayarlananKok != null) return _ayarlananKok!;
    return _socketUrlTanimi.isEmpty ? _derlemeKoku : _socketUrlTanimi;
  }

  /// Kullanıcının elle ayarladığı adres var mı
  static bool get adresAyarlandi => _ayarlananKok != null;

  /// Uygulama açılışında, herhangi bir istek atılmadan önce çağrılır.
  static Future<void> yukle() async {
    final kayitli = await SecureStorage.sunucuAdresiAl();
    if (kayitli != null && kayitli.isNotEmpty) {
      _ayarlananKok = kayitli;
    }
  }

  static Future<void> sunucuAdresiAyarla(String girdi) async {
    final adres = adresDuzelt(girdi);
    _ayarlananKok = adres;
    await SecureStorage.sunucuAdresiKaydet(adres);
  }

  /// Kullanıcının yazdığı adresi tam biçime getirir.
  ///
  /// `192.168.1.5` → `http://192.168.1.5:5000`
  /// `192.168.1.5:5000/api/v1` → `http://192.168.1.5:5000`
  static String adresDuzelt(String girdi) {
    var adres = girdi.trim();
    if (adres.isEmpty) return adres;

    adres = adres.replaceFirst(RegExp(r'/+$'), '');
    adres = adres.replaceFirst(RegExp(r'/api/v\d+/?$'), '');

    if (!RegExp(r'^https?://').hasMatch(adres)) {
      adres = 'http://$adres';
    }

    // Port yazılmadıysa sunucunun varsayılanı eklenir
    final ayristirilan = Uri.tryParse(adres);
    if (ayristirilan != null && !ayristirilan.hasPort) {
      adres = '$adres:5000';
    }

    return adres;
  }

  /// Girilen adresin kullanılabilir olup olmadığını söyler; hatalıysa
  /// kullanıcıya gösterilecek mesajı döner.
  static String? adresHatasi(String girdi) {
    if (girdi.trim().isEmpty) return 'Sunucu adresi boş bırakılamaz';

    final ayristirilan = Uri.tryParse(adresDuzelt(girdi));
    if (ayristirilan == null || ayristirilan.host.isEmpty) {
      return 'Geçerli bir adres girin, örnek: 192.168.1.5:5000';
    }

    return null;
  }

  /// Sunucu göreli yol dönüyor (`/uploads/...`); tam adres burada
  /// birleştiriliyor, böylece sunucunun adresi değiştiğinde veritabanındaki
  /// kayıtlara dokunmak gerekmiyor. Eski kayıtlar mutlak adresle yazılmıştı,
  /// onlar olduğu gibi dönüyor.
  static String medyaUrl(String yol) {
    if (yol.isEmpty || yol.startsWith('http')) return yol;

    return yol.startsWith('/') ? '$sunucuKoku$yol' : '$sunucuKoku/$yol';
  }

  static const Duration baglantiSuresi = Duration(seconds: 15);
  static const Duration yanitSuresi = Duration(seconds: 20);

  static const int mesajSayfaBoyutu = 30;
}
