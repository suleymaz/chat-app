import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/config/app_config.dart';
import '../../core/storage/secure_storage.dart';
import '../models/message_model.dart';

// Socket olaylarinin tasindigi tipler
class YeniMesajOlayi {
  final MessageModel mesaj;
  YeniMesajOlayi(this.mesaj);
}

class IletildiOlayi {
  final String conversationId;
  final List<String> messageIds;
  final DateTime deliveredAt;

  IletildiOlayi({
    required this.conversationId,
    required this.messageIds,
    required this.deliveredAt,
  });
}

class OkunduOlayi {
  final String conversationId;
  final DateTime readAt;

  OkunduOlayi({required this.conversationId, required this.readAt});
}

class MesajSilindiOlayi {
  final String conversationId;
  final String messageId;

  MesajSilindiOlayi({required this.conversationId, required this.messageId});
}

class YaziyorOlayi {
  final String conversationId;
  final String userId;
  final bool isTyping;

  YaziyorOlayi({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });
}

class DurumOlayi {
  final String userId;
  final bool cevrimici;
  final DateTime? lastSeenAt;

  DurumOlayi({required this.userId, required this.cevrimici, this.lastSeenAt});
}

class SocketService {
  io.Socket? _socket;
  bool _baglaniyor = false;

  // socket.connected baglanti kurulduktan hemen sonra yanlis sonuc verebiliyor,
  // durumu kendi bayragimizla takip ediyoruz
  bool _bagliMi = false;

  // Bir baglanti dongusunde token yenilemeyi yalnizca bir kez deneriz. Sunucuya
  // hic ulasilamadiginda her hatada yenileme atmak gereksiz istek uretiyordu.
  bool _yenilemeDenendi = false;

  // Basarisiz yeniden baglanma sayisi - bekleme suresi buna gore artar
  int _denemeSayisi = 0;

  final _yeniMesaj = StreamController<YeniMesajOlayi>.broadcast();
  final _iletildi = StreamController<IletildiOlayi>.broadcast();
  final _okundu = StreamController<OkunduOlayi>.broadcast();
  final _mesajSilindi = StreamController<MesajSilindiOlayi>.broadcast();
  final _yaziyor = StreamController<YaziyorOlayi>.broadcast();
  final _durum = StreamController<DurumOlayi>.broadcast();
  final _baglantiDurumu = StreamController<bool>.broadcast();

  Stream<YeniMesajOlayi> get yeniMesaj => _yeniMesaj.stream;
  Stream<IletildiOlayi> get iletildi => _iletildi.stream;
  Stream<OkunduOlayi> get okundu => _okundu.stream;
  Stream<MesajSilindiOlayi> get mesajSilindi => _mesajSilindi.stream;
  Stream<YaziyorOlayi> get yaziyor => _yaziyor.stream;
  Stream<DurumOlayi> get durum => _durum.stream;
  Stream<bool> get baglantiDurumu => _baglantiDurumu.stream;

  bool get bagli => _bagliMi;

  // Token yenileme icin disaridan verilen fonksiyon
  Future<bool> Function()? tokenYenile;

  Future<void> baglan() async {
    if (_baglaniyor) return;
    if (_bagliMi) return;

    _baglaniyor = true;

    try {
      var token = await SecureStorage.accessTokenAl();
      if (token == null) return;

      // Token suresi dolmussa once yenile, yoksa socket auth basarisiz oluyor
      if (_tokenSuresiDolmus(token)) {
        final yenilendi = await tokenYenile?.call() ?? false;
        if (!yenilendi) return;

        token = await SecureStorage.accessTokenAl();
        if (token == null) return;
      }

      _oncekiniKapat();

      // Polling uzerinden websocket'e yukseltme akisi sorun cikardigi icin
      // dogrudan websocket kullaniyoruz.
      // setForceNew: socket_io_client ayni adres icin Manager'i onbellege alip
      // yeniden kullaniyor; o zaman ilk baglantidaki token'a takili kaliyor ve
      // token yenilendikten sonra bile eski token'la el sikisiyor.
      _socket = io.io(
        AppConfig.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .enableForceNew()
            .build(),
      );

      // Yeniden baglanmalarda el sikismaya guncel token gitsin
      _socket!.auth = {'token': token};

      _dinleyicileriKur();
      _socket!.connect();
    } finally {
      _baglaniyor = false;
    }
  }

  // JWT payload'indaki exp alanini okuyup suresi dolmus mu bakar
  bool _tokenSuresiDolmus(String token) {
    try {
      final parcalar = token.split('.');
      if (parcalar.length != 3) return true;

      final cozulmus = utf8.decode(base64Url.decode(base64Url.normalize(parcalar[1])));
      final veri = jsonDecode(cozulmus) as Map<String, dynamic>;

      final exp = veri['exp'] as int?;
      if (exp == null) return true;

      final sonKullanma = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

      // 10 saniye pay birakiyoruz
      return DateTime.now().isAfter(sonKullanma.subtract(const Duration(seconds: 10)));
    } catch (_) {
      return true;
    }
  }

  void _dinleyicileriKur() {
    final socket = _socket;
    if (socket == null) return;

    socket.onConnect((_) {
      _bagliMi = true;
      _yenilemeDenendi = false;
      _denemeSayisi = 0;
      _baglantiDurumu.add(true);
    });

    socket.onDisconnect((_) {
      _bagliMi = false;
      _baglantiDurumu.add(false);
    });

    socket.onConnectError((hata) async {
      _bagliMi = false;
      _baglantiDurumu.add(false);

      // Token suresi dolmus olabilir - yenileyip tekrar dene.
      // Sunucu erisilemezse her hatada yenilemeye calismanin anlami yok,
      // bu dongude bir kez denenir; gerisini socket.io'nun kendi
      // yeniden baglanmasi ve onReconnectFailed ustleniyor.
      if (_yenilemeDenendi) return;
      _yenilemeDenendi = true;

      final yenilendi = await tokenYenile?.call() ?? false;
      if (!yenilendi) return;

      await Future.delayed(const Duration(milliseconds: 300));
      await baglan();
    });

    // Sunucu yeniden baslatildiginda otomatik yeniden baglanma tukenebiliyor,
    // o durumda sifirdan baglaniyoruz. Bekleme her denemede uzar.
    socket.onReconnectFailed((_) async {
      _bagliMi = false;
      _denemeSayisi++;

      final saniye = (3 * _denemeSayisi).clamp(3, 60);
      await Future.delayed(Duration(seconds: saniye));
      await baglan();
    });

    socket.onReconnectError((_) {
      _bagliMi = false;
      _baglantiDurumu.add(false);
    });

    socket.on('message:new', (veri) {
      final mesaj = MessageModel.fromJson(Map<String, dynamic>.from(veri));
      _yeniMesaj.add(YeniMesajOlayi(mesaj));
    });

    socket.on('message:delivered', (veri) {
      final harita = Map<String, dynamic>.from(veri);
      _iletildi.add(IletildiOlayi(
        conversationId: harita['conversationId'] as String,
        messageIds: (harita['messageIds'] as List).cast<String>(),
        deliveredAt: DateTime.parse(harita['deliveredAt'] as String),
      ));
    });

    socket.on('message:read', (veri) {
      final harita = Map<String, dynamic>.from(veri);
      _okundu.add(OkunduOlayi(
        conversationId: harita['conversationId'] as String,
        readAt: DateTime.parse(harita['readAt'] as String),
      ));
    });

    socket.on('message:deleted', (veri) {
      final harita = Map<String, dynamic>.from(veri);
      _mesajSilindi.add(MesajSilindiOlayi(
        conversationId: harita['conversationId'] as String,
        messageId: harita['messageId'] as String,
      ));
    });

    socket.on('typing', (veri) {
      final harita = Map<String, dynamic>.from(veri);
      _yaziyor.add(YaziyorOlayi(
        conversationId: harita['conversationId'] as String,
        userId: harita['userId'] as String,
        isTyping: harita['isTyping'] as bool,
      ));
    });

    socket.on('user:online', (veri) {
      final harita = Map<String, dynamic>.from(veri);
      _durum.add(DurumOlayi(userId: harita['userId'] as String, cevrimici: true));
    });

    socket.on('user:offline', (veri) {
      final harita = Map<String, dynamic>.from(veri);
      _durum.add(DurumOlayi(
        userId: harita['userId'] as String,
        cevrimici: false,
        lastSeenAt: harita['lastSeenAt'] != null
            ? DateTime.parse(harita['lastSeenAt'] as String)
            : null,
      ));
    });
  }

  void sohbeteKatil(String conversationId) {
    _socket?.emit('conversation:join', {'conversationId': conversationId});
  }

  void sohbettenAyril(String conversationId) {
    _socket?.emit('conversation:leave', {'conversationId': conversationId});
  }

  void yaziyorBaslat(String conversationId) {
    _socket?.emit('typing:start', {'conversationId': conversationId});
  }

  void yaziyorBitir(String conversationId) {
    _socket?.emit('typing:stop', {'conversationId': conversationId});
  }

  /// Eski socket'i ve onu tasiyan Manager'i tamamen kapatir.
  ///
  /// Sadece dispose() yetmiyor: dispose yalnizca socket'i kapatiyor, Manager'in
  /// kendi yeniden baglanma dongusu ayakta kaliyor. Ayakta kalan Manager ise
  /// olusturuldugu andaki token ile el sikismaya devam ediyor; token yenilendigi
  /// halde sunucuda "jwt expired" uyarilari birikiyordu. Once dinleyiciler
  /// temizleniyor ki kapatma sirasinda onConnectError tetiklenip yeniden
  /// baglanma zinciri baslatmasin.
  void _oncekiniKapat() {
    final socket = _socket;
    _socket = null;

    if (socket == null) return;

    socket.clearListeners();
    socket.io.close();
    socket.dispose();
  }

  // Cikis yapildiginda cagriliyor - yeniden baglanma denemeleri de durur
  void kopar() {
    _bagliMi = false;
    _yenilemeDenendi = false;
    _denemeSayisi = 0;

    _oncekiniKapat();

    _baglantiDurumu.add(false);
  }

  void temizle() {
    _bagliMi = false;
    _oncekiniKapat();
  }
}