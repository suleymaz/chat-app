class ApiException implements Exception {
  final String message;
  final String code;
  final int? statusCode;
  final Map<String, String>? alanHatalari;

  ApiException({
    required this.message,
    this.code = 'ERROR',
    this.statusCode,
    this.alanHatalari,
  });

  bool get agHatasi => code == 'NETWORK_ERROR' || code == 'TIMEOUT';
  bool get yetkisiz => statusCode == 401;

  @override
  String toString() => message;
}