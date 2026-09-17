import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/tarih_formatla.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/message_provider.dart';
import '../../widgets/gun_ayraci.dart';
import '../../widgets/kullanici_avatar.dart';
import '../../widgets/mesaj_balonu.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../providers/socket_provider.dart';
import '../../widgets/yaziyor_gostergesi.dart';


class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? userId;

  const ChatScreen({super.key, required this.conversationId, this.userId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _mesajController = TextEditingController();
  final _scrollController = ScrollController();

  UserModel? _karsiTaraf;
  bool _karsiTarafYukleniyor = true;
    Timer? _yaziyorZamanlayici;
  bool _yaziyorGonderildi = false;

  // "yeni" ise henuz sohbet olusmamis demektir
  bool get _yeniSohbet => widget.conversationId == 'yeni';

  MesajParam get _param => MesajParam(
        conversationId: _yeniSohbet ? null : widget.conversationId,
        karsiTarafId: widget.userId,
        benimId: ref.read(authProvider).kullanici?.id ?? '',
      );

    @override
  void initState() {
    super.initState();
    _scrollController.addListener(_kaydirmaDinle);
    _mesajController.addListener(_yazmaDinle);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _karsiTarafiYukle();

      if (!_yeniSohbet) {
        ref.read(socketServiceProvider).sohbeteKatil(widget.conversationId);
        ref.read(mesajProvider(_param).notifier).okunduIsaretle();
        ref.read(sohbetListesiProvider.notifier).okunduIsaretle(widget.conversationId);
      }
    });
  }

    @override
  void dispose() {
    if (!_yeniSohbet) {
      ref.read(socketServiceProvider).sohbettenAyril(widget.conversationId);
      if (_yaziyorGonderildi) {
        ref.read(socketServiceProvider).yaziyorBitir(widget.conversationId);
      }
    }

    _yaziyorZamanlayici?.cancel();
    _mesajController.removeListener(_yazmaDinle);
    _scrollController.removeListener(_kaydirmaDinle);
    _scrollController.dispose();
    _mesajController.dispose();
    super.dispose();
  }

  // Liste ters oldugu icin "yukari kaydirma" maxScrollExtent'e yaklasmak demek
  void _kaydirmaDinle() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(mesajProvider(_param).notifier).eskileriYukle();
    }
  }

    // Kullanici yazarken karsi tarafa bildirim gonderir
  void _yazmaDinle() {
    if (_yeniSohbet) return;

    final bosMu = _mesajController.text.trim().isEmpty;

    if (bosMu) {
      if (_yaziyorGonderildi) {
        ref.read(socketServiceProvider).yaziyorBitir(widget.conversationId);
        _yaziyorGonderildi = false;
      }
      _yaziyorZamanlayici?.cancel();
      return;
    }

    if (!_yaziyorGonderildi) {
      ref.read(socketServiceProvider).yaziyorBaslat(widget.conversationId);
      _yaziyorGonderildi = true;
    }

    // Yazmayi birakirsa 2 saniye sonra durdur
    _yaziyorZamanlayici?.cancel();
    _yaziyorZamanlayici = Timer(const Duration(seconds: 2), () {
      if (_yaziyorGonderildi) {
        ref.read(socketServiceProvider).yaziyorBitir(widget.conversationId);
        _yaziyorGonderildi = false;
      }
    });
  }

  Future<void> _karsiTarafiYukle() async {
    try {
      if (_yeniSohbet && widget.userId != null) {
        final kullanici = await ref.read(userRepositoryProvider).kullaniciGetir(widget.userId!);
        if (mounted) setState(() => _karsiTaraf = kullanici);
      } else {
        final detay = await ref.read(chatRepositoryProvider).sohbetDetay(widget.conversationId);
        if (mounted) setState(() => _karsiTaraf = detay);
      }
    } catch (_) {
      // Karsi taraf yuklenemezse baslikta id gosterilir
    } finally {
      if (mounted) setState(() => _karsiTarafYukleniyor = false);
    }
  }

  Future<void> _gonder() async {
    final icerik = _mesajController.text.trim();
    if (icerik.isEmpty) return;

    _mesajController.clear();

        if (_yaziyorGonderildi) {
      ref.read(socketServiceProvider).yaziyorBitir(widget.conversationId);
      _yaziyorGonderildi = false;
    }
    _yaziyorZamanlayici?.cancel();

    await ref.read(mesajProvider(_param).notifier).mesajGonder(icerik);

    _enAltaKaydir();

    // Yeni sohbet olustuysa listeyi tazele
    final notifier = ref.read(mesajProvider(_param).notifier);
    if (_yeniSohbet && notifier.olusanSohbetId != null) {
      ref.read(sohbetListesiProvider.notifier).tazele();
    } else {
      ref.read(sohbetListesiProvider.notifier).tazele();
    }
  }

  void _enAltaKaydir() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _mesajMenusu(MessageModel mesaj) {
    final benimMi = mesaj.senderId == ref.read(authProvider).kullanici?.id;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mesaj.content != null && mesaj.content!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Kopyala'),
                onTap: () {
                  Navigator.pop(context);
                  _kopyala(mesaj.content!);
                },
              ),
            if (benimMi && mesaj.durum != MesajDurumu.basarisiz)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Sil', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(mesajProvider(_param).notifier).mesajSil(mesaj.id);
                },
              ),
            if (benimMi && mesaj.durum == MesajDurumu.basarisiz)
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.error),
                title: const Text('Kaldir', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(mesajProvider(_param).notifier).mesajiKaldir(mesaj.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _kopyala(String metin) {
    Clipboard.setData(ClipboardData(text: metin));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mesaj kopyalandi'), duration: Duration(seconds: 1)),
    );
  }

    @override
  Widget build(BuildContext context) {
    final durum = ref.watch(mesajProvider(_param));
    final benimId = ref.watch(authProvider).kullanici?.id ?? '';
    final yaziyor = ref.watch(yaziyorProvider)[widget.conversationId] ?? false;

    // Sohbet ekrani acikken gelen mesajlari okundu isaretle
    ref.listen(mesajProvider(_param), (onceki, yeni) {
      final oncekiSayi = onceki?.mesajlar.length ?? 0;
      if (yeni.mesajlar.length > oncekiSayi && !_yeniSohbet) {
        final sonMesaj = yeni.mesajlar.first;
        if (sonMesaj.senderId != benimId) {
          ref.read(mesajProvider(_param).notifier).okunduIsaretle();
        }
      }
    });

    return Scaffold(
      appBar: _baslik(yaziyor),
      body: Column(
        children: [
          Expanded(child: _mesajListesi(durum, benimId)),
          if (yaziyor) const YaziyorGostergesi(),
          _girisAlani(),
        ],
      ),
    );
  }

    PreferredSizeWidget _baslik(bool yaziyor) {
    final cevrimiciHarita = ref.watch(cevrimiciProvider);
    final cevrimici = _karsiTaraf != null
        ? (cevrimiciHarita[_karsiTaraf!.id] ?? _karsiTaraf!.isOnline)
        : false;

    return AppBar(
      titleSpacing: 0,
      title: _karsiTarafYukleniyor
          ? const Text('Yukleniyor...')
          : Row(
              children: [
                KullaniciAvatar(
                  avatarUrl: _karsiTaraf?.avatarUrl,
                  basHarfler: _karsiTaraf?.basHarfler ?? '?',
                  boyut: 36,
                  cevrimici: cevrimici,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _karsiTaraf?.fullName ?? 'Sohbet',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (_karsiTaraf != null)
                        Text(
                          yaziyor
                              ? 'yaziyor...'
                              : cevrimici
                                  ? 'cevrimici'
                                  : 'son gorulme ${TarihFormat.sonGorulme(_karsiTaraf!.lastSeenAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: yaziyor || cevrimici
                                ? AppColors.online
                                : AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _mesajListesi(MesajDurum durum, String benimId) {
    if (durum.yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    if (durum.hata != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(durum.hata!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(mesajProvider(_param).notifier).ilkYukleme(),
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }

    if (durum.mesajlar.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.waving_hand_outlined, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                _karsiTaraf != null
                    ? '${_karsiTaraf!.fullName} ile sohbete basla'
                    : 'Sohbete basla',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: durum.mesajlar.length + (durum.eskiYukleniyor ? 1 : 0),
      itemBuilder: (context, index) {
        // Ters listede son eleman en eski mesaj - yukleme gostergesi orada
        if (index == durum.mesajlar.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final mesaj = durum.mesajlar[index];
        final benimMi = mesaj.senderId == benimId;

        // Bir sonraki (daha eski) mesaj farkli gunde ise ayrac koy
        final sonraki = index + 1 < durum.mesajlar.length ? durum.mesajlar[index + 1] : null;
        final gunDegisti = sonraki == null || !_ayniGun(mesaj.createdAt, sonraki.createdAt);

        return Column(
          children: [
            MesajBalonu(
              mesaj: mesaj,
              benimMi: benimMi,
              onUzunBas: () => _mesajMenusu(mesaj),
              onTekrarDene: () =>
                  ref.read(mesajProvider(_param).notifier).tekrarGonder(mesaj.id),
            ),
            if (gunDegisti) GunAyraci(tarih: mesaj.createdAt),
          ],
        );
      },
    );
  }

  bool _ayniGun(DateTime a, DateTime b) {
    final ay = a.toLocal();
    final by = b.toLocal();
    return ay.year == by.year && ay.month == by.month && ay.day == by.day;
  }

  Widget _girisAlani() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _mesajController,
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _gonder(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _gonder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}