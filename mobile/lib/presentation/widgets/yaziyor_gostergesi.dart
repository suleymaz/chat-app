import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class YaziyorGostergesi extends StatefulWidget {
  const YaziyorGostergesi({super.key});

  @override
  State<YaziyorGostergesi> createState() => _YaziyorGostergesiState();
}

class _YaziyorGostergesiState extends State<YaziyorGostergesi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.mesajGelen,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) => _nokta(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nokta(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Her nokta sirayla yukari zipliyor
        final ilerleme = (_controller.value - index * 0.2) % 1.0;
        final yukseklik = ilerleme < 0.5 ? (ilerleme * 2) : (2 - ilerleme * 2);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Transform.translate(
            offset: Offset(0, -3 * yukseklik),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}