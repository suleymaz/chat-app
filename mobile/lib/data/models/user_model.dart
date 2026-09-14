class UserModel {
  final String id;
  final String username;
  final String? email;
  final String? phone;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final bool notificationsEnabled;
  final String notificationPreview;

  UserModel({
    required this.id,
    required this.username,
    this.email,
    this.phone,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.isOnline = false,
    this.lastSeenAt,
    this.notificationsEnabled = true,
    this.notificationPreview = 'NAME_AND_MESSAGE',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'] as String)
          : null,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      notificationPreview: json['notificationPreview'] as String? ?? 'NAME_AND_MESSAGE',
    );
  }

  UserModel copyWith({
    String? fullName,
    String? avatarUrl,
    String? bio,
    bool? isOnline,
    DateTime? lastSeenAt,
    bool? notificationsEnabled,
    String? notificationPreview,
  }) {
    return UserModel(
      id: id,
      username: username,
      email: email,
      phone: phone,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationPreview: notificationPreview ?? this.notificationPreview,
    );
  }

  // Ad soyadin bas harfleri - avatar yoksa gosterilir
  String get basHarfler {
    final parcalar = fullName.trim().split(RegExp(r'\s+'));
    if (parcalar.isEmpty) return '?';
    if (parcalar.length == 1) return parcalar[0][0].toUpperCase();
    return (parcalar[0][0] + parcalar[parcalar.length - 1][0]).toUpperCase();
  }
}