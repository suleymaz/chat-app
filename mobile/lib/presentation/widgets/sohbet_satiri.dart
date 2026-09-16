import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/tarih_formatla.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import 'kullanici_avatar.dart';

class SohbetSatiri extends StatelessWidget {
  final ConversationModel sohbet;
  final String benimId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SohbetSatiri({
    super.key,
    required this.sohbet,
    required this.benimId,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final okunmamisVar = sohbet.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            KullaniciAvatar(
              avatarUrl: sohbet.user.avatarUrl,
              basHarfler: sohbet.user.basHarfler,
              cevrimici: sohbet.user.isOnline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sohbet.user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: okunmamisVar ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        TarihFormat.sohbetListesi(sohbet.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: okunmamisVar ? AppColors.primary : AppColors.textTertiary,
                          fontWeight: okunmamisVar ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_benimMesajim) ...[
                        _durumIkonu(),
                        const SizedBox(width: 4),
                      ],
                      if (_ekIkonu != null) ...[
                        Icon(_ekIkonu, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          sohbet.sonMesajOzeti,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: okunmamisVar
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: okunmamisVar ? FontWeight.w500 : FontWeight.normal,
                            fontStyle: (sohbet.lastMessage?.silinmis ?? false)
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (sohbet.isMuted) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.notifications_off_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                      ],
                      if (okunmamisVar) ...[
                        const SizedBox(width: 6),
                        _okunmamisRozeti(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _benimMesajim => sohbet.lastMessage?.senderId == benimId;

  IconData? get _ekIkonu {
    final mesaj = sohbet.lastMessage;
    if (mesaj == null || mesaj.silinmis) return null;

    switch (mesaj.type) {
      case MesajTipi.image:
        return Icons.photo_outlined;
      case MesajTipi.file:
        return Icons.insert_drive_file_outlined;
      case MesajTipi.text:
        return null;
    }
  }

  Widget _durumIkonu() {
    final mesaj = sohbet.lastMessage;
    if (mesaj == null || mesaj.silinmis) return const SizedBox.shrink();

    if (mesaj.readAt != null) {
      return const Icon(Icons.done_all, size: 15, color: AppColors.primary);
    }
    if (mesaj.deliveredAt != null) {
      return const Icon(Icons.done_all, size: 15, color: AppColors.textTertiary);
    }
    return const Icon(Icons.done, size: 15, color: AppColors.textTertiary);
  }

  Widget _okunmamisRozeti() {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        sohbet.unreadCount > 99 ? '99+' : '${sohbet.unreadCount}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}