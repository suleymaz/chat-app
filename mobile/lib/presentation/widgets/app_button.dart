import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String metin;
  final VoidCallback? onPressed;
  final bool yukleniyor;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.metin,
    this.onPressed,
    this.yukleniyor = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: yukleniyor ? null : onPressed,
        child: yukleniyor
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(metin),
                ],
              ),
      ),
    );
  }
}