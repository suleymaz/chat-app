import '../../core/network/api_client.dart';

class NotificationRepository {
  final ApiClient _client;

  NotificationRepository(this._client);

  // Cihazin FCM token'ini sunucuya bildirir - bildirim gonderilebilmesi icin sart
  Future<void> cihazKaydet({required String fcmToken, required String platform}) async {
    await _client.dio.post('/notifications/token', data: {
      'fcmToken': fcmToken,
      'platform': platform,
    });
  }

  Future<void> cihazSil(String fcmToken) async {
    await _client.dio.delete('/notifications/token', data: {'fcmToken': fcmToken});
  }
}
