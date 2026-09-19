import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Mesaj eklerini uygulamaya ozel klasore indirir ve sistem uygulamasiyla acar.
///
/// Uygulamanin kendi klasorune yazdigi icin Android/iOS'ta ek depolama izni
/// gerekmiyor. Ayni dosya ikinci kez istenirse tekrar indirilmez.
class DosyaIndirici {
  final Dio _dio;

  DosyaIndirici() : _dio = Dio();

  Future<String> indir({
    required String url,
    required String dosyaAdi,
    required String mesajId,
  }) async {
    final dizin = await getApplicationDocumentsDirectory();
    final klasor = Directory('${dizin.path}/ekler');

    if (!await klasor.exists()) {
      await klasor.create(recursive: true);
    }

    // Ayni adli dosyalar birbirini ezmesin diye mesaj id'si on ek olarak ekleniyor
    final yol = '${klasor.path}/${mesajId}_${_guvenliAd(dosyaAdi)}';
    final dosya = File(yol);

    if (await dosya.exists() && await dosya.length() > 0) {
      return yol;
    }

    await _dio.download(url, yol);
    return yol;
  }

  /// Dosyayi sistemin varsayilan uygulamasiyla acar.
  /// Acilamazsa kullaniciya gosterilecek mesaji doner, acildiysa null doner.
  Future<String?> ac(String yol) async {
    final sonuc = await OpenFilex.open(yol);

    switch (sonuc.type) {
      case ResultType.done:
        return null;
      case ResultType.noAppToOpen:
        return 'Bu dosya turunu acabilecek bir uygulama bulunamadi';
      case ResultType.permissionDenied:
        return 'Dosyayi acmak icin izin verilmedi';
      case ResultType.fileNotFound:
        return 'Dosya bulunamadi';
      case ResultType.error:
        return 'Dosya acilamadi';
    }
  }

  // Dosya adindaki klasor ayraclarini ve sorunlu karakterleri temizler
  String _guvenliAd(String ad) => ad.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
