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
import '../../providers/socket_provider.dart';
import '../../../data/models/conversation_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // Ekran acildiginda listeyi tazele - giris sonrasi ilk yukleme
    // auth tamamlanmadan yapilmis olabiliyor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sohbetListesiProvider.notifier).tazele();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sohbetler = ref.watch(sohbetListesiProvider);
    final benimId = ref.watch(authProvider).kullanici?.id ?? '';
    final kullanici = ref.watch(authProvider).kullanici;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbetler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Arsiv',
            onPressed: () => context.push(Rotalar.archive),
          ),
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
                final cevrimiciHarita = ref.watch(cevrimiciProvider);
                final cevrimici =
                    cevrimiciHarita[sohbet.user.id]?.cevrimici ?? sohbet.user.isOnline;

                return SohbetSatiri(
                  sohbet: sohbet.copyWith(
                    user: sohbet.user.copyWith(isOnline: cevrimici),
                  ),
                  benimId: benimId,
                  onTap: () => context.push('${Rotalar.chat}/${sohbet.id}'),
                  onLongPress: () => _sohbetMenusu(sohbet),
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

  void _sohbetMenusu(ConversationModel sohbet) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                sohbet.user.fullName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Arsivle'),
              onTap: () {
                Navigator.pop(context);
                _arsivle(sohbet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Sohbeti sil', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _silmeOnayi(sohbet);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _silmeOnayi(ConversationModel sohbet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbet silinsin mi?'),
        content: Text(
          '${sohbet.user.fullName} ile olan sohbet ve mesaj gecmisi sizin icin '
          'silinecek. Karsi taraf sohbeti gormeye devam eder; tekrar yazisirsaniz '
          'sohbet bos olarak yeniden baslar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgec'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sil(sohbet);
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _arsivle(ConversationModel sohbet) async {
    final basarili = await ref.read(sohbetListesiProvider.notifier).arsivle(sohbet.id, true);
    if (!mounted) return;

    if (!basarili) {
      _uyari('Sohbet arsivlenemedi, baglantini kontrol et');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sohbet.user.fullName} arsivlendi'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => _arsivdenCikar(sohbet),
        ),
      ),
    );
  }

  Future<void> _arsivdenCikar(ConversationModel sohbet) async {
    final basarili = await ref.read(arsivListesiProvider.notifier).arsivle(sohbet.id, false);
    if (!mounted) return;

    if (!basarili) {
      _uyari('Geri alinamadi, baglantini kontrol et');
      return;
    }

    await ref.read(sohbetListesiProvider.notifier).tazele();
  }

  Future<void> _sil(ConversationModel sohbet) async {
    final basarili = await ref.read(sohbetListesiProvider.notifier).sil(sohbet.id);
    if (!mounted) return;

    if (!basarili) {
      _uyari('Sohbet silinemedi, baglantini kontrol et');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sohbet.user.fullName} ile olan sohbet silindi'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _uyari(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: AppColors.error),
    );
  }
}
