import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/socket_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('tr', null);

  runApp(const ProviderScope(child: ChatApp()));
}

class ChatApp extends ConsumerStatefulWidget {
  const ChatApp({super.key});

  @override
  ConsumerState<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends ConsumerState<ChatApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authProvider.notifier).baslat();

      // Oturum zaten aciksa socket'i baglat
      if (ref.read(authProvider).durum == OturumDurumu.girisYapildi) {
        ref.read(socketKoordinatorProvider).basla();
        await ref.read(socketServiceProvider).baglan();
      }
    });
  }

  @override
  void dispose() {
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

        // Token'in depoya yazilmasini bekle
        await Future.delayed(const Duration(milliseconds: 300));
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