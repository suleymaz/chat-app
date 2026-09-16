import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/tarih_formatla.dart';

class GunAyraci extends StatelessWidget {
  final DateTime tarih;

  const GunAyraci({super.key, required this.tarih});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            TarihFormat.gunAyraci(tarih),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}