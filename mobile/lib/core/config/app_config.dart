class AppConfig {
  // Build sirasinda --dart-define=API_URL=... ile degistirilebilir
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Sunucu gorsel ve dosya adreslerini goreli donuyor (/uploads/...).
  /// Tam adres burada birlestiriliyor, boylece sunucunun adresi degistiginde
  /// veritabanindaki kayitlara dokunmak gerekmiyor.
  ///
  /// Eski kayitlar mutlak adresle yazilmisti; onlar oldugu gibi donuyor.
  /// Sunucu koku, API adresinden turetiliyor. socketUrl'den turetseydik
  /// yalnizca API_URL verilip SOCKET_URL verilmeyen bir derlemede gorseller
  /// sessizce yanlis adrese giderdi.
  static String get sunucuKoku => apiUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');

  static String medyaUrl(String yol) {
    if (yol.isEmpty || yol.startsWith('http')) return yol;

    return yol.startsWith('/') ? '$sunucuKoku$yol' : '$sunucuKoku/$yol';
  }

  static const Duration baglantiSuresi = Duration(seconds: 15);
  static const Duration yanitSuresi = Duration(seconds: 20);

  static const int mesajSayfaBoyutu = 30;
}