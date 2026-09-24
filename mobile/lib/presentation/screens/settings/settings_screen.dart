import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/baglanti_seridi.dart';

// Bildirim onizleme secenekleri - sunucudaki enum ile birebir ayni
const _onizlemeSecenekleri = {
  'NAME_AND_MESSAGE': ('Ad ve mesaj', 'Bildirimde gönderen ve mesaj içeriği görünür'),
  'NAME_ONLY': ('Sadece ad', 'Yalnızca gönderenin adı görünür'),
  'NONE': ('Gizle', 'Bildirimde hiçbir detay görünmez'),
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _kaydediliyor = false;

  // Ayar degisiklikleri once ekranda uygulanir, istek basarisizsa geri alinir
  Future<void> _ayarGuncelle(Map<String, dynamic> veriler) async {
    if (_kaydediliyor) return;

    setState(() => _kaydediliyor = true);

    try {
      final guncel = await ref.read(userRepositoryProvider).profilGuncelle(veriler);
      ref.read(authProvider.notifier).kullaniciGuncelle(guncel);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ayar kaydedilemedi, bağlantını kontrol et'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  Future<void> _cikisOnayi() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text('Tekrar mesajlaşmak için yeniden giriş yapman gerekecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgec'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış yap', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (onay != true) return;

    await ref.read(authProvider.notifier).cikisYap();
  }

  @override
  Widget build(BuildContext context) {
    final kullanici = ref.watch(authProvider).kullanici;
    final bildirimAcik = kullanici?.notificationsEnabled ?? true;
    final onizleme = kullanici?.notificationPreview ?? 'NAME_AND_MESSAGE';

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: Column(
        children: [
          const BaglantiSeridi(),
          Expanded(
              child: ListView(
            children: [
              _baslik('Bildirimler'),
              SwitchListTile(
                value: bildirimAcik,
                onChanged: _kaydediliyor
                    ? null
                    : (deger) => _ayarGuncelle({'notificationsEnabled': deger}),
                title: const Text('Bildirimlere izin ver'),
                subtitle: const Text('Yeni mesaj geldiğinde bildirim gönderilir'),
                activeThumbColor: AppColors.primary,
              ),
              const Divider(height: 1),

              _baslik('Bildirim onizlemesi'),
              RadioGroup<String>(
                groupValue: onizleme,
                onChanged: (deger) {
                  if (deger == null || !bildirimAcik || _kaydediliyor) return;
                  _ayarGuncelle({'notificationPreview': deger});
                },
                child: Column(
                  children: [
                    for (final giris in _onizlemeSecenekleri.entries)
                      RadioListTile<String>(
                        value: giris.key,
                        enabled: bildirimAcik && !_kaydediliyor,
                        title: Text(giris.value.$1),
                        subtitle: Text(
                          giris.value.$2,
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                        activeColor: AppColors.primary,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              _baslik('Gizlilik'),
              ListTile(
                leading: const Icon(Icons.block_outlined, color: AppColors.textSecondary),
                title: const Text('Engellenen kullanıcılar'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                onTap: () => context.push(Rotalar.blocked),
              ),
              const Divider(height: 1),

              _baslik('Hesap'),
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                title: Text(kullanici?.fullName ?? ''),
                subtitle: Text('@${kullanici?.username ?? ''}'),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Çıkış yap', style: TextStyle(color: AppColors.error)),
                onTap: _cikisOnayi,
              ),
              const SizedBox(height: 24),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _baslik(String metin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        metin.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
