import 'message_model.dart';
import 'user_model.dart';

class ConversationModel {
  final String id;
  final UserModel user;
  final MessageModel? lastMessage;
  final int unreadCount;
  final bool isMuted;
  final bool isArchived;
  final DateTime? lastMessageAt;

  ConversationModel({
    required this.id,
    required this.user,
    this.lastMessage,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isArchived = false,
    this.lastMessageAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isMuted: json['isMuted'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
    );
  }

  ConversationModel copyWith({
    UserModel? user,
    MessageModel? lastMessage,
    int? unreadCount,
    bool? isMuted,
    bool? isArchived,
    DateTime? lastMessageAt,
  }) {
    return ConversationModel(
      id: id,
      user: user ?? this.user,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  // Sohbet listesinde gosterilecek son mesaj ozeti
  String get sonMesajOzeti {
    if (lastMessage == null) return '';
    if (lastMessage!.silinmis) return 'Bu mesaj silindi';

    switch (lastMessage!.type) {
      case MesajTipi.image:
        return 'Fotograf';
      case MesajTipi.file:
        return lastMessage!.attachments.isNotEmpty
            ? (lastMessage!.attachments.first.fileName ?? 'Dosya')
            : 'Dosya';
      case MesajTipi.text:
        return lastMessage!.content ?? '';
    }
  }
}