import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/tarih_formatla.dart';

/// Sohbetteki gorseli tam ekran gosterir. Parmakla yakinlastirilabilir.
class GorselOnizleme extends StatelessWidget {
  final String? url;
  final String? yerelYol;
  final String baslik;
  final DateTime tarih;

  const GorselOnizleme({
    super.key,
    this.url,
    this.yerelYol,
    required this.baslik,
    required this.tarih,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              baslik,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              '${TarihFormat.gunAyraci(tarih)} · ${TarihFormat.mesajSaati(tarih)}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: _gorsel(),
        ),
      ),
    );
  }

  Widget _gorsel() {
    if (yerelYol != null) {
      return Image.file(
        File(yerelYol!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _hata(),
      );
    }

    if (url == null) return _hata();

    return CachedNetworkImage(
      imageUrl: AppConfig.medyaUrl(url!),
      fit: BoxFit.contain,
      placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
      errorWidget: (context, url, error) => _hata(),
    );
  }

  Widget _hata() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, size: 56, color: Colors.white54),
        SizedBox(height: 12),
        Text('Görsel yüklenemedi', style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}
