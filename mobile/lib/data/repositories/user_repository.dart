import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

class UserRepository {
  final ApiClient _client;

  UserRepository(this._client);

  Future<UserModel> profilimiGetir() async {
    final yanit = await _client.dio.get('/users/me');
    return UserModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  Future<UserModel> profilGuncelle(Map<String, dynamic> veriler) async {
    final yanit = await _client.dio.patch('/users/me', data: veriler);
    return UserModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  Future<void> sifreDegistir({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.dio.patch('/users/me/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<UserModel> avatarYukle(String dosyaYolu) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(dosyaYolu),
    });

    final yanit = await _client.dio.post('/users/me/avatar', data: formData);
    return UserModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  Future<UserModel> avatarSil() async {
    final yanit = await _client.dio.delete('/users/me/avatar');
    return UserModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  Future<List<UserModel>> kullaniciAra(String terim) async {
    final yanit = await _client.dio.get('/users/search', queryParameters: {'q': terim});

    return (yanit.data['data'] as List)
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> kullaniciGetir(String userId) async {
    final yanit = await _client.dio.get('/users/$userId');
    return UserModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  Future<void> engelle(String userId) async {
    await _client.dio.post('/users/$userId/block');
  }

  Future<void> engelKaldir(String userId) async {
    await _client.dio.delete('/users/$userId/block');
  }

  Future<List<UserModel>> engellenenler() async {
    final yanit = await _client.dio.get('/users/me/blocked');

    return (yanit.data['data'] as List)
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}