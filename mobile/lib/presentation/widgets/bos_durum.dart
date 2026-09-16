import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BosDurum extends StatelessWidget {
  final IconData icon;
  final String baslik;
  final String? aciklama;
  final Widget? aksiyon;

  const BosDurum({
    super.key,
    required this.icon,
    required this.baslik,
    this.aciklama,
    this.aksiyon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              baslik,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (aciklama != null) ...[
              const SizedBox(height: 6),
              Text(
                aciklama!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
              ),
            ],
            if (aksiyon != null) ...[
              const SizedBox(height: 20),
              aksiyon!,
            ],
          ],
        ),
      ),
    );
  }
}