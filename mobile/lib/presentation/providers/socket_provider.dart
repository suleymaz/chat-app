import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/socket_service.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';
import 'message_provider.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final servis = SocketService();

  // Yenileme ApiClient uzerinden yapilir. Socket'in kendi yenilemesi olsaydi
  // ayni anda iki istek ayni refresh token'i harcar ve sunucu oturumu kapatirdi.
  servis.tokenYenile = ref.read(apiClientProvider).tokenYenile;

  ref.onDispose(servis.temizle);
  return servis;
});

// Socket baglanti durumu - ekranlarda gostermek icin
final socketBagliProvider = StreamProvider<bool>((ref) {
  return ref.watch(socketServiceProvider).baglantiDurumu;
});

// Bir sohbette karsi tarafin yazip yazmadigi
final yaziyorProvider = StateNotifierProvider<YaziyorNotifier, Map<String, bool>>((ref) {
  return YaziyorNotifier();
});

class YaziyorNotifier extends StateNotifier<Map<String, bool>> {
  YaziyorNotifier() : super({});

  final Map<String, Timer> _zamanlayicilar = {};

  void guncelle(String conversationId, bool yaziyor) {
    state = {...state, conversationId: yaziyor};

    _zamanlayicilar[conversationId]?.cancel();

    // Karsi taraf typing:stop gondermezse 4 saniye sonra kendiliginden kapansin
    if (yaziyor) {
      _zamanlayicilar[conversationId] = Timer(const Duration(seconds: 4), () {
        state = {...state, conversationId: false};
      });
    }
  }

  @override
  void dispose() {
    for (final t in _zamanlayicilar.values) {
      t.cancel();
    }
    super.dispose();
  }
}

// Kullanicilarin cevrimici durumu - socket'ten gelen guncellemeler burada tutulur
final cevrimiciProvider = StateNotifierProvider<CevrimiciNotifier, Map<String, bool>>((ref) {
  return CevrimiciNotifier();
});

class CevrimiciNotifier extends StateNotifier<Map<String, bool>> {
  CevrimiciNotifier() : super({});

  void guncelle(String userId, bool cevrimici) {
    state = {...state, userId: cevrimici};
  }
}

// Socket olaylarini ilgili provider'lara dagitan katman.
// Socket servisi Riverpod'u bilmiyor, dagitim isi burada yapiliyor.
class SocketKoordinator {
  final Ref _ref;
  final List<StreamSubscription> _abonelikler = [];

  SocketKoordinator(this._ref);

  void basla() {
    final servis = _ref.read(socketServiceProvider);

    _abonelikler.add(servis.yeniMesaj.listen(_yeniMesajGeldi));
    _abonelikler.add(servis.iletildi.listen(_iletildiGeldi));
    _abonelikler.add(servis.okundu.listen(_okunduGeldi));
    _abonelikler.add(servis.mesajSilindi.listen(_mesajSilindi));
    _abonelikler.add(servis.yaziyor.listen(_yaziyorGeldi));
    _abonelikler.add(servis.durum.listen(_durumGeldi));
  }

  MesajParam _param(String conversationId) {
    final benimId = _ref.read(authProvider).kullanici?.id ?? '';
    return MesajParam(conversationId: conversationId, benimId: benimId);
  }

  void _yeniMesajGeldi(YeniMesajOlayi olay) {
    final param = _param(olay.mesaj.conversationId);

    // Sohbet ekrani acikken mesaji listeye ekle
    if (_ref.exists(mesajProvider(param))) {
      _ref.read(mesajProvider(param).notifier).mesajEkle(olay.mesaj);
    }

    // Sohbet listesi tazelenince ilgili sohbet ustte cikar
    _ref.read(sohbetListesiProvider.notifier).tazelemeIste();
  }

  // Bu olay sadece tik durumunu etkiliyor, liste sirasini degistirmiyor.
  // O yuzden sohbet listesi tazelenmiyor.
  void _iletildiGeldi(IletildiOlayi olay) {
    final param = _param(olay.conversationId);

    if (_ref.exists(mesajProvider(param))) {
      _ref.read(mesajProvider(param).notifier).iletildiIsaretle(
            olay.messageIds,
            olay.deliveredAt,
          );
    }
  }

  void _okunduGeldi(OkunduOlayi olay) {
    final param = _param(olay.conversationId);

    if (_ref.exists(mesajProvider(param))) {
      _ref.read(mesajProvider(param).notifier).okunduIsaretleYerel(olay.readAt);
    }
  }

  void _mesajSilindi(MesajSilindiOlayi olay) {
    final param = _param(olay.conversationId);

    if (_ref.exists(mesajProvider(param))) {
      _ref.read(mesajProvider(param).notifier).mesajSilindiIsaretle(olay.messageId);
    }

    // Son mesaj silindiyse listede "Bu mesaj silindi" gorunmeli
    _ref.read(sohbetListesiProvider.notifier).tazelemeIste();
  }

  void _yaziyorGeldi(YaziyorOlayi olay) {
    _ref.read(yaziyorProvider.notifier).guncelle(olay.conversationId, olay.isTyping);
  }

  // Cevrimici durumu cevrimiciProvider uzerinden okunuyor,
  // sohbet listesini tazelemeye gerek yok
  void _durumGeldi(DurumOlayi olay) {
    _ref.read(cevrimiciProvider.notifier).guncelle(olay.userId, olay.cevrimici);
  }

  void dur() {
    for (final abonelik in _abonelikler) {
      abonelik.cancel();
    }
    _abonelikler.clear();
  }
}

final socketKoordinatorProvider = Provider<SocketKoordinator>((ref) {
  final koordinator = SocketKoordinator(ref);
  ref.onDispose(koordinator.dur);
  return koordinator;
});