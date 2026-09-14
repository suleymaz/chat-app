import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  Future<UserModel> kayitOl({
    required String username,
    required String email,
    required String phone,
    required String fullName,
    required String password,
  }) async {
    final yanit = await _client.dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'phone': phone,
      'fullName': fullName,
      'password': password,
    });

    return _oturumAc(yanit);
  }

  Future<UserModel> girisYap({
    required String identifier,
    required String password,
  }) async {
    final yanit = await _client.dio.post('/auth/login', data: {
      'identifier': identifier,
      'password': password,
    });

    return _oturumAc(yanit);
  }

  Future<void> cikisYap() async {
    final refreshToken = await SecureStorage.refreshTokenAl();

    try {
      await _client.dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {
      // Sunucuya ulasilamasa bile yerel token'lar silinir
    }

    await SecureStorage.temizle();
  }

  Future<UserModel> _oturumAc(Response yanit) async {
    final veri = yanit.data['data'];

    await SecureStorage.tokenKaydet(
      accessToken: veri['accessToken'] as String,
      refreshToken: veri['refreshToken'] as String,
    );

    final kullanici = UserModel.fromJson(veri['user'] as Map<String, dynamic>);
    await SecureStorage.userIdKaydet(kullanici.id);

    return kullanici;
  }
}