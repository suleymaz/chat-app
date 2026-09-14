enum MesajTipi { text, image, file }

enum MesajDurumu { gonderiliyor, gonderildi, iletildi, okundu, basarisiz }

class AttachmentModel {
  final String id;
  final String url;
  final String? fileName;
  final String mimeType;
  final int sizeBytes;
  final int? width;
  final int? height;

  AttachmentModel({
    required this.id,
    required this.url,
    this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.width,
    this.height,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] as String,
      url: json['url'] as String,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String,
      sizeBytes: json['sizeBytes'] as int,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  String get okunurBoyut {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final MesajTipi type;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final List<AttachmentModel> attachments;

  // Sadece istemci tarafinda kullanilir - optimistic UI icin
  final MesajDurumu? yerelDurum;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.type = MesajTipi.text,
    this.deliveredAt,
    this.readAt,
    this.deletedAt,
    required this.createdAt,
    this.attachments = const [],
    this.yerelDurum,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String,
      content: json['content'] as String?,
      type: _tipCevir(json['type'] as String?),
      deliveredAt: _tarih(json['deliveredAt']),
      readAt: _tarih(json['readAt']),
      deletedAt: _tarih(json['deletedAt']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      attachments: (json['attachments'] as List?)
              ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static DateTime? _tarih(dynamic deger) =>
      deger != null ? DateTime.parse(deger as String) : null;

  static MesajTipi _tipCevir(String? tip) {
    switch (tip) {
      case 'IMAGE':
        return MesajTipi.image;
      case 'FILE':
        return MesajTipi.file;
      default:
        return MesajTipi.text;
    }
  }

  bool get silinmis => deletedAt != null;

  // Gonderen icin mesajin hangi asamada oldugunu doner
  MesajDurumu get durum {
    if (yerelDurum != null) return yerelDurum!;
    if (readAt != null) return MesajDurumu.okundu;
    if (deliveredAt != null) return MesajDurumu.iletildi;
    return MesajDurumu.gonderildi;
  }

  MessageModel copyWith({
    String? id,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? deletedAt,
    MesajDurumu? yerelDurum,
    List<AttachmentModel>? attachments,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      content: deletedAt != null ? null : content,
      type: type,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      attachments: attachments ?? this.attachments,
      yerelDurum: yerelDurum,
    );
  }
}