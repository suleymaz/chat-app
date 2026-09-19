import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/home/archive_screen.dart';
import '../../presentation/screens/profile/sifre_degistir_ekrani.dart';
import '../../presentation/screens/settings/engellenenler_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';

class Rotalar {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const search = '/search';
  static const chat = '/chat';
  static const profile = '/profile';
  static const archive = '/archive';
  static const settings = '/settings';
  static const changePassword = '/settings/password';
  static const blocked = '/settings/blocked';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: Rotalar.splash,
    redirect: (context, state) {
      final durum = authState.durum;
      final yol = state.matchedLocation;

      if (durum == OturumDurumu.baslangic) {
        return yol == Rotalar.splash ? null : Rotalar.splash;
      }

      final authEkraninda = yol == Rotalar.login || yol == Rotalar.register;

      if (durum == OturumDurumu.girisYapilmadi) {
        return authEkraninda ? null : Rotalar.login;
      }

      if (authEkraninda || yol == Rotalar.splash) {
        return Rotalar.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Rotalar.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Rotalar.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Rotalar.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Rotalar.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Rotalar.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: Rotalar.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '${Rotalar.chat}/:id',
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['id']!,
          userId: state.uri.queryParameters['userId'],
        ),
      ),
      GoRoute(
        path: Rotalar.archive,
        builder: (context, state) => const ArchiveScreen(),
      ),
      GoRoute(
        path: Rotalar.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Rotalar.changePassword,
        builder: (context, state) => const SifreDegistirEkrani(),
      ),
      GoRoute(
        path: Rotalar.blocked,
        builder: (context, state) => const EngellenenlerScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Sayfa bulunamadi: ${state.uri}')),
    ),
  );
});