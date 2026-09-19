import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/conversation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/bos_durum.dart';
import '../../widgets/sohbet_satiri.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(arsivListesiProvider.notifier).tazele();
    });
  }

  // Once istek tamamlanmali: beklemeden ana listeyi tazelersek sunucu henuz
  // guncellenmemis olabiliyor ve sohbet ana listede gorunmuyordu.
  Future<void> _arsivdenCikar(ConversationModel sohbet) async {
    final basarili = await ref.read(arsivListesiProvider.notifier).arsivle(sohbet.id, false);
    if (!mounted) return;

    if (!basarili) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arsivden cikarilamadi, baglantini kontrol et'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await ref.read(sohbetListesiProvider.notifier).tazele();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sohbet.user.fullName} arsivden cikarildi'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sohbetler = ref.watch(arsivListesiProvider);
    final benimId = ref.watch(authProvider).kullanici?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Arsiv')),
      body: sohbetler.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (hata, _) => BosDurum(
          icon: Icons.cloud_off_outlined,
          baslik: 'Arsiv yuklenemedi',
          aksiyon: FilledButton(
            onPressed: () => ref.read(arsivListesiProvider.notifier).yukle(),
            child: const Text('Tekrar dene'),
          ),
        ),
        data: (liste) {
          if (liste.isEmpty) {
            return const BosDurum(
              icon: Icons.archive_outlined,
              baslik: 'Arsiv bos',
              aciklama: 'Arsivledigin sohbetler burada gorunur',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(arsivListesiProvider.notifier).tazele(),
            child: ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (context, index) => const Divider(indent: 80, height: 1),
              itemBuilder: (context, index) {
                final sohbet = liste[index];

                return SohbetSatiri(
                  sohbet: sohbet,
                  benimId: benimId,
                  onTap: () => context.push('${Rotalar.chat}/${sohbet.id}'),
                  onLongPress: () => _arsivdenCikarMenusu(sohbet),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _arsivdenCikarMenusu(ConversationModel sohbet) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.unarchive_outlined),
              title: const Text('Arsivden cikar'),
              onTap: () {
                Navigator.pop(context);
                _arsivdenCikar(sohbet);
              },
            ),
          ],
        ),
      ),
    );
  }
}