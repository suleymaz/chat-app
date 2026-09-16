import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/tarih_formatla.dart';
import '../../data/models/message_model.dart';

class MesajBalonu extends StatelessWidget {
  final MessageModel mesaj;
  final bool benimMi;
  final VoidCallback? onUzunBas;
  final VoidCallback? onTekrarDene;

  const MesajBalonu({
    super.key,
    required this.mesaj,
    required this.benimMi,
    this.onUzunBas,
    this.onTekrarDene,
  });

  @override
  Widget build(BuildContext context) {
    final basarisiz = mesaj.durum == MesajDurumu.basarisiz;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment: benimMi ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (benimMi && basarisiz) ...[
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: AppColors.error),
              onPressed: onTekrarDene,
              visualDensity: VisualDensity.compact,
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: mesaj.silinmis ? null : onUzunBas,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: mesaj.type == MesajTipi.image && !mesaj.silinmis
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: benimMi ? AppColors.mesajGiden : AppColors.mesajGelen,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(benimMi ? 16 : 4),
                    bottomRight: Radius.circular(benimMi ? 4 : 16),
                  ),
                  border: benimMi ? null : Border.all(color: AppColors.border),
                ),
                child: _icerik(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icerik() {
    if (mesaj.silinmis) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(
            'Bu mesaj silindi',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          _saatVeDurum(),
        ],
      );
    }

    switch (mesaj.type) {
      case MesajTipi.image:
        return _gorsel();
      case MesajTipi.file:
        return _dosya();
      case MesajTipi.text:
        return _metin();
    }
  }

  Widget _metin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          mesaj.content ?? '',
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.3),
        ),
        const SizedBox(height: 2),
        _saatVeDurum(),
      ],
    );
  }

  Widget _gorsel() {
    final ek = mesaj.attachments.isNotEmpty ? mesaj.attachments.first : null;
    if (ek == null) return _metin();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
            imageUrl: ek.url,
            width: 220,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 220,
              height: 160,
              color: AppColors.border,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 220,
              height: 160,
              color: AppColors.border,
              child: const Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
            ),
          ),
        ),
        if (mesaj.content != null && mesaj.content!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              mesaj.content!,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
          child: _saatVeDurum(),
        ),
      ],
    );
  }

  Widget _dosya() {
    final ek = mesaj.attachments.isNotEmpty ? mesaj.attachments.first : null;
    if (ek == null) return _metin();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.insert_drive_file_outlined,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ek.fileName ?? 'Dosya',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    ek.okunurBoyut,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _saatVeDurum(),
      ],
    );
  }

  Widget _saatVeDurum() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TarihFormat.mesajSaati(mesaj.createdAt),
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        if (benimMi) ...[
          const SizedBox(width: 4),
          _durumIkonu(),
        ],
      ],
    );
  }

  Widget _durumIkonu() {
    switch (mesaj.durum) {
      case MesajDurumu.gonderiliyor:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textTertiary),
        );
      case MesajDurumu.basarisiz:
        return const Icon(Icons.error_outline, size: 13, color: AppColors.error);
      case MesajDurumu.okundu:
        return const Icon(Icons.done_all, size: 14, color: AppColors.primary);
      case MesajDurumu.iletildi:
        return const Icon(Icons.done_all, size: 14, color: AppColors.textTertiary);
      case MesajDurumu.gonderildi:
        return const Icon(Icons.done, size: 14, color: AppColors.textTertiary);
    }
  }
}