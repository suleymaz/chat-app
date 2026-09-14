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

  static const Duration baglantiSuresi = Duration(seconds: 15);
  static const Duration yanitSuresi = Duration(seconds: 20);

  static const int mesajSayfaBoyutu = 30;
}