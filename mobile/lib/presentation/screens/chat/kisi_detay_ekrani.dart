import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/tarih_formatla.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/socket_provider.dart';
import '../../widgets/kullanici_avatar.dart';

/// Sohbet başlığındaki isme dokununca açılan kişi kartı.
///
/// Sohbet ekranının elindeki kullanıcı nesnesi sohbet detayından geliyor ve
/// yalnızca başlıkta gereken alanları taşıyor. İletişim bilgileri için profil
/// ayrıca çekiliyor; bu sayede telefon ve e-posta her sohbet yanıtında
/// taşınmıyor, sadece kart açıldığında isteniyor.
class KisiDetayEkrani extends ConsumerStatefulWidget {
  final UserModel kullanici;

  const KisiDetayEkrani({super.key, required this.kullanici});

  @override
  ConsumerState<KisiDetayEkrani> createState() => _KisiDetayEkraniState();
}

class _KisiDetayEkraniState extends ConsumerState<KisiDetayEkrani> {
  late UserModel _kullanici = widget.kullanici;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _profiliYukle());
  }

  Future<void> _profiliYukle() async {
    try {
      final tam = await ref.read(userRepositoryProvider).kullaniciGetir(_kullanici.id);
      if (mounted) setState(() => _kullanici = tam);
    } catch (_) {
      // Profil çekilemezse başlıktaki bilgilerle yetiniyoruz
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kart açıkken karşı taraf çevrimiçi olabilir, canlı durumu dinliyoruz
    final durum = ref.watch(cevrimiciProvider)[_kullanici.id];
    final cevrimici = durum?.cevrimici ?? _kullanici.isOnline;
    final sonGorulme = durum?.lastSeenAt ?? _kullanici.lastSeenAt;

    final bio = _kullanici.bio?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Kişi bilgileri')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                KullaniciAvatar(
                  avatarUrl: _kullanici.avatarUrl,
                  basHarfler: _kullanici.basHarfler,
                  boyut: 112,
                ),
                const SizedBox(height: 16),
                Text(
                  _kullanici.fullName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  cevrimici
                      ? 'çevrimiçi'
                      : 'son görülme ${TarihFormat.sonGorulme(sonGorulme)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cevrimici ? AppColors.online : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _satir(
            icon: Icons.alternate_email,
            baslik: 'Kullanıcı adı',
            deger: '@${_kullanici.username}',
          ),
          if (bio.isNotEmpty)
            _satir(icon: Icons.info_outline, baslik: 'Hakkında', deger: bio),
          if (_kullanici.phone != null)
            _satir(
              icon: Icons.phone_outlined,
              baslik: 'Telefon',
              deger: _kullanici.phone!,
            ),
          if (_kullanici.email != null)
            _satir(
              icon: Icons.mail_outline,
              baslik: 'E-posta',
              deger: _kullanici.email!,
            ),
          if (_yukleniyor)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _satir({
    required IconData icon,
    required String baslik,
    required String deger,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon, color: AppColors.textTertiary),
      title: Text(
        deger,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        baslik,
        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    );
  }
}
