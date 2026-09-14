import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';

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

class _ChatAppState extends ConsumerState<ChatApp> {
  @override
  void initState() {
    super.initState();

    // Interceptor oturumu kapatirsa auth state'i de guncellensin
    ref.read(apiClientProvider).oturumKapandi = () {
      ref.read(authProvider.notifier).oturumSonlandir();
    };

    // Kayitli token varsa oturumu geri yukle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).baslat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}