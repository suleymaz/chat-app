import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/home_screen.dart';

class Rotalar {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: Rotalar.splash,
    redirect: (context, state) {
      final durum = authState.durum;
      final yol = state.matchedLocation;

      // Oturum kontrolu tamamlanana kadar splash'te bekle
      if (durum == OturumDurumu.baslangic) {
        return yol == Rotalar.splash ? null : Rotalar.splash;
      }

      final authEkraninda = yol == Rotalar.login || yol == Rotalar.register;

      // Giris yapilmamissa auth ekranlarina yonlendir
      if (durum == OturumDurumu.girisYapilmadi) {
        return authEkraninda ? null : Rotalar.login;
      }

      // Giris yapilmissa auth ekranlarindan uzaklastir
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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Sayfa bulunamadi: ${state.uri}')),
    ),
  );
});