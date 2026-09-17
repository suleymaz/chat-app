import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Interceptor oturumu kapatirsa socket de kapansin
    ref.read(apiClientProvider).oturumKapandi = () {
      ref.read(socketServiceProvider).kopar();
      ref.read(authProvider.notifier).oturumSonlandir();
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authProvider.notifier).baslat();

      // Uygulama acilisinda oturum zaten aciksa socket'i baglat
      if (ref.read(authProvider).durum == OturumDurumu.girisYapildi) {
        ref.read(socketKoordinatorProvider).basla();
        await ref.read(socketServiceProvider).baglan();
      }
    });

    // Sunucu yeniden baslatilirsa veya ag kesilirse socket kopuyor.
    // Belirli araliklarla kontrol edip yeniden baglaniyoruz.
        _baglantiKontrol = Timer.periodic(const Duration(seconds: 30), (_) {
      final girisYapildi = ref.read(authProvider).durum == OturumDurumu.girisYapildi;
      if (!girisYapildi) return;

      final servis = ref.read(socketServiceProvider);
      if (!servis.bagli) {
        servis.baglan();
      }
    });
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
    final girisYapildi = ref.read(authProvider).durum == OturumDurumu.girisYapildi;
    if (!girisYapildi) return;

    switch (durum) {
      case AppLifecycleState.resumed:
        ref.read(socketServiceProvider).baglan();
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

        // Token'in depoya yazilmasini bekle, yoksa socket eski token'la baglaniyor
        await Future.delayed(const Duration(milliseconds: 500));
        await ref.read(socketServiceProvider).baglan();
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