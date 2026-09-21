import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../repositories/notification_repository.dart';

// Backend bildirimleri "messages" kanaliyla gonderiyor, kanal adi ayni olmali
const _kanalId = 'messages';

/// FCM kurulumu ve cihaz token kaydi.
///
/// Firebase yapilandirmasi yoksa (google-services.json eklenmemisse)
/// servis sessizce devre disi kalir, uygulamanin geri kalani calismaya devam eder.
class PushService {
  final NotificationRepository _repo;

  PushService(this._repo);

  final _yerelBildirim = FlutterLocalNotificationsPlugin();

  bool _hazir = false;
  String? _kayitliToken;
  StreamSubscription<String>? _tokenAbonelik;
  StreamSubscription<RemoteMessage>? _mesajAbonelik;
  StreamSubscription<RemoteMessage>? _acilisAbonelik;

  /// Bildirime dokunuldugunda ilgili sohbeti acar - main.dart tarafindan atanir
  void Function(String conversationId)? sohbetAc;

  /// Uygulama kapaliyken bildirime dokunulduysa sohbet id'si burada bekler.
  /// Acilista yonlendirme yapilamaz (oturum henuz yuklenmemis olabilir),
  /// bu yuzden oturum hazir olunca main.dart gelip aliyor.
  String? _bekleyenSohbetId;

  bool get hazir => _hazir;

  String? bekleyenSohbetIdAl() {
    final id = _bekleyenSohbetId;
    _bekleyenSohbetId = null;
    return id;
  }

  /// Uygulama acilisinda bir kez cagrilir
  Future<void> baslat() async {
    if (_hazir) return;

    // Masaustunde FCM desteklenmiyor
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      await Firebase.initializeApp();
    } catch (hata) {
      debugPrint('Firebase başlatılamadı, bildirimler devre dışı: $hata');
      return;
    }

    try {
      await _yerelBildirimiKur();
      _mesajAbonelik = FirebaseMessaging.onMessage.listen(_onPlandaGoster);

      // Uygulama arka plandayken bildirime dokunulursa
      _acilisAbonelik = FirebaseMessaging.onMessageOpenedApp.listen(_bildirimeDokunuldu);

      // Uygulama tamamen kapaliyken bildirime dokunulup acildiysa
      final acilisMesaji = await FirebaseMessaging.instance.getInitialMessage();
      if (acilisMesaji != null) {
        _bekleyenSohbetId = _sohbetIdCikar(acilisMesaji);
      }

      _hazir = true;
    } catch (hata) {
      debugPrint('Bildirim kurulumu başarısız: $hata');
    }
  }

  // Backend bildirim verisinde conversationId gonderiyor
  String? _sohbetIdCikar(RemoteMessage mesaj) {
    final id = mesaj.data['conversationId'];
    return (id is String && id.isNotEmpty) ? id : null;
  }

  void _bildirimeDokunuldu(RemoteMessage mesaj) {
    final id = _sohbetIdCikar(mesaj);
    if (id == null) return;

    if (sohbetAc != null) {
      sohbetAc!(id);
    } else {
      _bekleyenSohbetId = id;
    }
  }

  /// Giris yapildiktan sonra cagrilir - token sunucuya kaydedilir
  Future<void> tokenKaydet() async {
    if (!_hazir) return;

    try {
      final izin = await FirebaseMessaging.instance.requestPermission();

      // Izin verilmediyse bildirim gorunmez ama token yine de kaydedilir:
      // kullanici sistem ayarlarindan izni actiginda tekrar giris yapmak
      // zorunda kalmasin. Izin bir kez reddedildikten sonra requestPermission
      // bir daha pencere acmaz, bu yuzden burada durursak cihaz hic kaydolmaz.
      if (izin.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('Bildirim izni durumu: ${izin.authorizationStatus}');
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _sunucuyaBildir(token);

      // Token yenilenirse sunucudaki kayit da guncellenmeli
      await _tokenAbonelik?.cancel();
      _tokenAbonelik = FirebaseMessaging.instance.onTokenRefresh.listen(_sunucuyaBildir);
    } catch (hata) {
      debugPrint('FCM token kaydedilemedi: $hata');
    }
  }

  /// Uygulama one geldiginde cagrilir. Ilk denemede kaydedilemeyen token
  /// (izin penceresi kapatilmis, sunucuya ulasilamamis) burada tekrar denenir.
  Future<void> tokenKaydetGerekiyorsa() async {
    if (_kayitliToken != null) return;
    await tokenKaydet();
  }

  /// Cikis yaparken cagrilir - bu cihaza artik bildirim gitmemeli.
  /// Token'lar hala gecerliyken, yani oturum kapanmadan once calistirilmali.
  Future<void> tokenSil() async {
    await _tokenAbonelik?.cancel();
    _tokenAbonelik = null;

    final token = _kayitliToken;
    _kayitliToken = null;

    if (token == null) return;

    try {
      await _repo.cihazSil(token);
    } catch (hata) {
      // Sunucuya ulasilamazsa da cikis akisi devam eder; gecersiz token'lari
      // backend gonderim sirasinda zaten temizliyor.
      debugPrint('FCM token silinemedi: $hata');
    }
  }

  Future<void> _sunucuyaBildir(String token) async {
    try {
      await _repo.cihazKaydet(fcmToken: token, platform: Platform.isIOS ? 'ios' : 'android');
      _kayitliToken = token;
    } catch (hata) {
      debugPrint('FCM token sunucuya bildirilemedi: $hata');
    }
  }

  Future<void> _yerelBildirimiKur() async {
    const ayarlar = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    // On plandaki bildirime dokunulunca payload'daki sohbet id'si ile aciliyor
    await _yerelBildirim.initialize(
      ayarlar,
      onDidReceiveNotificationResponse: (yanit) {
        final id = yanit.payload;
        if (id == null || id.isEmpty) return;

        if (sohbetAc != null) {
          sohbetAc!(id);
        } else {
          _bekleyenSohbetId = id;
        }
      },
    );

    const kanal = AndroidNotificationChannel(
      _kanalId,
      'Mesajlar',
      description: 'Yeni mesaj bildirimleri',
      importance: Importance.high,
    );

    await _yerelBildirim
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(kanal);
  }

  // Uygulama on plandayken sistem bildirimi gostermez, kendimiz gosteriyoruz
  Future<void> _onPlandaGoster(RemoteMessage mesaj) async {
    final bildirim = mesaj.notification;
    if (bildirim == null) return;

    await _yerelBildirim.show(
      mesaj.hashCode,
      bildirim.title,
      bildirim.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kanalId,
          'Mesajlar',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _sohbetIdCikar(mesaj),
    );
  }

  Future<void> temizle() async {
    await _tokenAbonelik?.cancel();
    await _mesajAbonelik?.cancel();
    await _acilisAbonelik?.cancel();
  }
}
