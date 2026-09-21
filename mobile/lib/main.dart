import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/socket_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Turkce tarih formatlari icin
  await initializeDateFormatting('tr', null);

  runApp(const ProviderScope(child: ChatApp()));
}

class ChatApp extends ConsumerStatefulWidget {
  const ChatApp({super.key});

  @override
  ConsumerState<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends ConsumerState<ChatApp> with WidgetsBindingObserver {
  Timer? _baglantiKontrol;

  // Uygulama ekranda mi - arka planda socket'e baglanmamak icin takip ediliyor
  bool _onPlanda = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Interceptor oturumu kapatirsa socket de kapansin
    ref.read(apiClientProvider).oturumKapandi = () {
      ref.read(socketServiceProvider).kopar();
      ref.read(pushServiceProvider).tokenSil();
      ref.read(authProvider.notifier).oturumSonlandir();
    };

    // Cikis yaparken FCM kaydi, token'lar hala gecerliyken silinmeli
    ref.read(authProvider.notifier).cikisOncesi =
        () => ref.read(pushServiceProvider).tokenSil();

    // Bildirime dokunulunca ilgili sohbet aciliyor. Oturum kapaliysa router
    // zaten giris ekranina yonlendirir.
    ref.read(pushServiceProvider).sohbetAc = _sohbeteGit;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Firebase yapilandirilmamissa sessizce devre disi kalir
      await ref.read(pushServiceProvider).baslat();

      await ref.read(authProvider.notifier).baslat();

      // Uygulama acilisinda oturum zaten aciksa socket'i baglat
      if (ref.read(authProvider).durum == OturumDurumu.girisYapildi) {
        ref.read(socketKoordinatorProvider).basla();
        await ref.read(socketServiceProvider).baglan();
        await ref.read(pushServiceProvider).tokenKaydet();

        // Uygulama bildirime dokunularak acildiysa o sohbete git
        final bekleyenSohbet = ref.read(pushServiceProvider).bekleyenSohbetIdAl();
        if (bekleyenSohbet != null && mounted) {
          _sohbeteGit(bekleyenSohbet);
        }
      }
    });

    // Sunucu yeniden baslatilirsa veya ag kesilirse socket kopuyor.
    // Belirli araliklarla kontrol edip yeniden baglaniyoruz.
    _baglantiKontrol = Timer.periodic(const Duration(seconds: 30), (_) {
      // Uygulama arka planda iken baglanmamali: backend bagli kullaniciya
      // bildirim gondermiyor. Timer arka planda da calismaya devam ettigi icin
      // bu kontrol olmazsa 30 saniye sonra socket geri geliyor ve kullanici
      // bildirim alamaz hale geliyor.
      if (!_onPlanda) return;

      final girisYapildi = ref.read(authProvider).durum == OturumDurumu.girisYapildi;
      if (!girisYapildi) return;

      final servis = ref.read(socketServiceProvider);
      if (!servis.bagli) {
        servis.baglan();
      }
    });
  }

  // Bildirimden gelen yonlendirme. Ayni sohbet zaten aciksa ustune ikinci bir
  // kopyasini acmiyoruz: acilan yeni ekran ayni provider'i paylastigi icin
  // mesajlari yeniden yuklemez, eski liste gorunur.
  void _sohbeteGit(String conversationId) {
    final router = ref.read(routerProvider);
    final yol = '${Rotalar.chat}/$conversationId';

    if (router.state.uri.path == yol) return;

    router.push(yol);
  }

  @override
  void dispose() {
    _baglantiKontrol?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Uygulama arka plana gecince socket kapanir, boylece backend FCM gonderir
  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    // Bayrak oturumdan bagimsiz tutulmali, giris yapilmadan once de dogru olsun
    if (durum == AppLifecycleState.resumed) _onPlanda = true;
    if (durum == AppLifecycleState.paused || durum == AppLifecycleState.detached) {
      _onPlanda = false;
    }

    final girisYapildi = ref.read(authProvider).durum == OturumDurumu.girisYapildi;
    if (!girisYapildi) return;

    switch (durum) {
      case AppLifecycleState.resumed:
        ref.read(socketServiceProvider).baglan();

        // Arka plandayken socket kapali oldugu icin gelen mesajlar listeye
        // dusmemis olabilir; one gelince listeler tazeleniyor.
        ref.read(sohbetListesiProvider.notifier).tazelemeIste();

        if (ref.exists(arsivListesiProvider)) {
          ref.read(arsivListesiProvider.notifier).tazelemeIste();
        }

        // Ilk acilista kaydedilemeyen FCM token'i icin ikinci sans
        ref.read(pushServiceProvider).tokenKaydetGerekiyorsa();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        ref.read(socketServiceProvider).kopar();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Oturum durumu degistiginde socket baglantisini yonet
    ref.listen<AuthState>(authProvider, (onceki, yeni) async {
      if (yeni.durum == OturumDurumu.girisYapildi &&
          onceki?.durum != OturumDurumu.girisYapildi) {
        ref.read(socketKoordinatorProvider).basla();

        // Token'lar AuthRepository tarafindan bu noktadan once yaziliyor,
        // ayrica socket baglanmadan once token suresini kendisi kontrol ediyor
        await ref.read(socketServiceProvider).baglan();
        await ref.read(pushServiceProvider).tokenKaydet();
      }

      if (yeni.durum == OturumDurumu.girisYapilmadi &&
          onceki?.durum == OturumDurumu.girisYapildi) {
        ref.read(socketServiceProvider).kopar();
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}