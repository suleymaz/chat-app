import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/bos_durum.dart';
import '../../widgets/kullanici_avatar.dart';
import '../../widgets/sohbet_satiri.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sohbetler = ref.watch(sohbetListesiProvider);
    final benimId = ref.watch(authProvider).kullanici?.id ?? '';
    final kullanici = ref.watch(authProvider).kullanici;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbetler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Kullanici ara',
            onPressed: () => context.push(Rotalar.search),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: GestureDetector(
              onTap: () => context.push(Rotalar.profile),
              child: Center(
                child: KullaniciAvatar(
                  avatarUrl: kullanici?.avatarUrl,
                  basHarfler: kullanici?.basHarfler ?? '?',
                  boyut: 34,
                ),
              ),
            ),
          ),
        ],
      ),
      body: sohbetler.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (hata, _) => _hataDurumu(ref),
        data: (liste) {
          if (liste.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(sohbetListesiProvider.notifier).tazele(),
              child: Stack(
                children: [
                  ListView(),
                  BosDurum(
                    icon: Icons.forum_outlined,
                    baslik: 'Henuz sohbetin yok',
                    aciklama: 'Birine mesaj gondererek baslayabilirsin',
                    aksiyon: FilledButton.icon(
                      onPressed: () => context.push(Rotalar.search),
                      icon: const Icon(Icons.person_search, size: 18),
                      label: const Text('Kullanici ara'),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(sohbetListesiProvider.notifier).tazele(),
            child: ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (context, index) => const Divider(indent: 80, height: 1),
              itemBuilder: (context, index) {
                final sohbet = liste[index];

                return SohbetSatiri(
                  sohbet: sohbet,
                  benimId: benimId,
                  onTap: () => context.push('${Rotalar.chat}/${sohbet.id}'),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Rotalar.search),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
    );
  }

  Widget _hataDurumu(WidgetRef ref) {
    return BosDurum(
      icon: Icons.cloud_off_outlined,
      baslik: 'Sohbetler yuklenemedi',
      aciklama: 'Internet baglantini kontrol edip tekrar dene',
      aksiyon: FilledButton.icon(
        onPressed: () => ref.read(sohbetListesiProvider.notifier).yukle(),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Tekrar dene'),
      ),
    );
  }
}