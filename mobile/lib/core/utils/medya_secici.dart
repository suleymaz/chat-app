import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

// Secilen dosyanin ekranlar icin sadelestirilmis hali
class SecilenDosya {
  final String yol;
  final String ad;
  final int boyut;

  SecilenDosya({required this.yol, required this.ad, required this.boyut});
}

/// Galeri, kamera ve dosya secme islemlerini tek yerde toplar.
/// Kullanici secimi iptal ederse null doner.
class MedyaSecici {
  static final _gorselSecici = ImagePicker();

  // Gorseller sunucuda da kucultuluyor, burada sadece kaba bir on sinir koyuyoruz
  static const _maksGenislik = 1920.0;
  static const _kalite = 88;

  static Future<String?> galeriden() async {
    final secilen = await _gorselSecici.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maksGenislik,
      imageQuality: _kalite,
    );

    return secilen?.path;
  }

  static Future<String?> kameradan() async {
    final secilen = await _gorselSecici.pickImage(
      source: ImageSource.camera,
      maxWidth: _maksGenislik,
      imageQuality: _kalite,
    );

    return secilen?.path;
  }

  static Future<SecilenDosya?> dosya() async {
    final sonuc = await FilePicker.platform.pickFiles();
    final dosya = sonuc?.files.singleOrNull;

    if (dosya?.path == null) return null;

    return SecilenDosya(
      yol: dosya!.path!,
      ad: dosya.name,
      boyut: dosya.size,
    );
  }
}
