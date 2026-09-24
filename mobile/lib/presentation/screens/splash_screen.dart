import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Uygulama simgesinin on katmani: telefondaki simgeyle ayni isaret
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/icon/icon_foreground.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lafla',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}