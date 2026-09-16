import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class KullaniciAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String basHarfler;
  final double boyut;
  final bool cevrimici;

  const KullaniciAvatar({
    super.key,
    this.avatarUrl,
    required this.basHarfler,
    this.boyut = 52,
    this.cevrimici = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boyut,
      height: boyut,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(boyut / 2),
            child: avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    width: boyut,
                    height: boyut,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _harfler(),
                    errorWidget: (context, url, error) => _harfler(),
                  )
                : _harfler(),
          ),
          if (cevrimici)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: boyut * 0.28,
                height: boyut * 0.28,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _harfler() {
    return Container(
      width: boyut,
      height: boyut,
      color: _renkUret(),
      alignment: Alignment.center,
      child: Text(
        basHarfler,
        style: TextStyle(
          fontSize: boyut * 0.36,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  // Bas harflerden sabit bir renk uretiyoruz - ayni kullanici hep ayni renkte
  Color _renkUret() {
    const renkler = [
      Color(0xFF5B8DEF),
      Color(0xFF9B6DD6),
      Color(0xFFE8825A),
      Color(0xFF3FAE8C),
      Color(0xFFD4626E),
      Color(0xFF5FA8C7),
    ];

    final kod = basHarfler.codeUnits.fold<int>(0, (a, b) => a + b);
    return renkler[kod % renkler.length];
  }
}