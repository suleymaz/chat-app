import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _sunucuAdresiKey = 'sunucu_adresi';

  static Future<void> tokenKaydet({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<String?> accessTokenAl() => _storage.read(key: _accessTokenKey);

  static Future<String?> refreshTokenAl() => _storage.read(key: _refreshTokenKey);

  static Future<void> userIdKaydet(String userId) =>
      _storage.write(key: _userIdKey, value: userId);

  static Future<String?> userIdAl() => _storage.read(key: _userIdKey);

  // Sunucu adresi kullaniciya ait bir sir degil, cihaza ait bir ayar.
  // Cikista silinmiyor; aksi halde her cikistan sonra yeniden girilmesi
  // gerekirdi.
  static Future<void> sunucuAdresiKaydet(String adres) =>
      _storage.write(key: _sunucuAdresiKey, value: adres);

  static Future<String?> sunucuAdresiAl() => _storage.read(key: _sunucuAdresiKey);

  /// Oturum bilgilerini siler. deleteAll() kullanilmiyor: sunucu adresi
  /// oturumdan bagimsiz bir cihaz ayari ve cikista kaybolmamali.
  static Future<void> temizle() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
  }
}