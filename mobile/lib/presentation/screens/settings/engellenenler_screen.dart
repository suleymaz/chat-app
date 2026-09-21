import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bos_durum.dart';
import '../../widgets/kullanici_avatar.dart';

class EngellenenlerScreen extends ConsumerStatefulWidget {
  const EngellenenlerScreen({super.key});

  @override
  ConsumerState<EngellenenlerScreen> createState() => _EngellenenlerScreenState();
}

class _EngellenenlerScreenState extends ConsumerState<EngellenenlerScreen> {
  List<UserModel> _kullanicilar = [];
  bool _yukleniyor = true;
  bool _hata = false;

  // Engeli kaldirilmakta olan kullanicilar
  final Set<String> _islemdekiler = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _yukle());
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = false;
    });

    try {
      final liste = await ref.read(userRepositoryProvider).engellenenler();
      if (!mounted) return;
      setState(() => _kullanicilar = liste);
    } catch (_) {
      if (mounted) setState(() => _hata = true);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _engelKaldir(UserModel kullanici) async {
    setState(() => _islemdekiler.add(kullanici.id));

    try {
      await ref.read(userRepositoryProvider).engelKaldir(kullanici.id);
      if (!mounted) return;

      setState(() => _kullanicilar.removeWhere((k) => k.id == kullanici.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${kullanici.fullName} için engel kaldırıldı')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Engel kaldırılamadı, bağlantını kontrol et'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _islemdekiler.remove(kullanici.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engellenen kullanıcılar')),
      body: _govde(),
    );
  }

  Widget _govde() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hata) {
      return BosDurum(
        icon: Icons.cloud_off_outlined,
        baslik: 'Liste yüklenemedi',
        aciklama: 'İnternet bağlantını kontrol edip tekrar dene',
        aksiyon: FilledButton.icon(
          onPressed: _yukle,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Tekrar dene'),
        ),
      );
    }

    if (_kullanicilar.isEmpty) {
      return const BosDurum(
        icon: Icons.block_outlined,
        baslik: 'Engellenen kullanıcı yok',
        aciklama: 'Engellediklerin burada listelenir',
      );
    }

    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView.separated(
        itemCount: _kullanicilar.length,
        separatorBuilder: (context, index) => const Divider(indent: 76, height: 1),
        itemBuilder: (context, index) {
          final kullanici = _kullanicilar[index];
          final islemde = _islemdekiler.contains(kullanici.id);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: KullaniciAvatar(
              avatarUrl: kullanici.avatarUrl,
              basHarfler: kullanici.basHarfler,
              boyut: 46,
            ),
            title: Text(
              kullanici.fullName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '@${kullanici.username}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            trailing: islemde
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () => _engelKaldir(kullanici),
                    child: const Text('Engeli kaldır'),
                  ),
          );
        },
      ),
    );
  }
}
