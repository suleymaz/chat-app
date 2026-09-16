import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class MesajSayfasi {
  final List<MessageModel> mesajlar;
  final String? nextCursor;
  final bool hasMore;

  MesajSayfasi({required this.mesajlar, this.nextCursor, required this.hasMore});
}

class ChatRepository {
  final ApiClient _client;

  ChatRepository(this._client);

  Future<List<ConversationModel>> sohbetleriGetir({bool arsivlenmis = false}) async {
    final yanit = await _client.dio.get(
      '/conversations',
      queryParameters: arsivlenmis ? {'archived': 'true'} : null,
    );

    return (yanit.data['data'] as List)
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> kullaniciylaSohbet(String userId) async {
    final yanit = await _client.dio.post('/conversations/with-user', data: {'userId': userId});
    return yanit.data['data'] as Map<String, dynamic>;
  }

    Future<MesajSayfasi> mesajlariGetir(String conversationId, {String? cursor}) async {
    final yanit = await _client.dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {
        ?cursor == null ? null : 'cursor': cursor,
        'limit': 30,
      },
    );

    final veri = yanit.data['data'];

    return MesajSayfasi(
      mesajlar: (veri['items'] as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: veri['nextCursor'] as String?,
      hasMore: veri['hasMore'] as bool? ?? false,
    );
  }

  Future<MessageModel> mesajGonder(String conversationId, String icerik) async {
    final yanit = await _client.dio.post(
      '/conversations/$conversationId/messages',
      data: {'content': icerik},
    );

    return MessageModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  // Yeni sohbet baslatir, sohbet id'si ve ilk mesaji doner
  Future<({String? conversationId, MessageModel message})> yeniSohbetBaslat({
    required String userId,
    required String icerik,
  }) async {
    final yanit = await _client.dio.post('/messages', data: {
      'userId': userId,
      'content': icerik,
    });

    final veri = yanit.data['data'];

    return (
      conversationId: veri['conversationId'] as String?,
      message: MessageModel.fromJson(veri['message'] as Map<String, dynamic>),
    );
  }

  Future<MessageModel> gorselGonder(String conversationId, String dosyaYolu, {String? icerik}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(dosyaYolu),
      if (icerik != null && icerik.isNotEmpty) 'content': icerik,
    });

    final yanit = await _client.dio.post(
      '/conversations/$conversationId/messages/image',
      data: formData,
    );

    return MessageModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  Future<MessageModel> dosyaGonder(String conversationId, String dosyaYolu, {String? icerik}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(dosyaYolu),
      if (icerik != null && icerik.isNotEmpty) 'content': icerik,
    });

    final yanit = await _client.dio.post(
      '/conversations/$conversationId/messages/file',
      data: formData,
    );

    return MessageModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  Future<MessageModel> mesajSil(String messageId) async {
    final yanit = await _client.dio.delete('/messages/$messageId');
    return MessageModel.fromJson(yanit.data['data'] as Map<String, dynamic>);
  }

  Future<List<MessageModel>> mesajAra(String conversationId, String terim) async {
    final yanit = await _client.dio.get(
      '/conversations/$conversationId/messages/search',
      queryParameters: {'q': terim},
    );

    return (yanit.data['data'] as List)
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> okunduIsaretle(String conversationId) async {
    await _client.dio.post('/conversations/$conversationId/read');
  }

  Future<void> arsivle(String conversationId, bool arsivle) async {
    await _client.dio.patch(
      '/conversations/$conversationId/archive',
      data: {'archived': arsivle},
    );
  }

  Future<void> sohbetSil(String conversationId) async {
    await _client.dio.delete('/conversations/$conversationId');
  }

    Future<UserModel> sohbetDetay(String conversationId) async {
    final yanit = await _client.dio.get('/conversations/$conversationId');
    final veri = yanit.data['data'];
    return UserModel.fromJson(veri['user'] as Map<String, dynamic>);
  }
}

