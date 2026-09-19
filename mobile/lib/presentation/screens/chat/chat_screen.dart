import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../core/config/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/medya_secici.dart';
import '../../../core/utils/tarih_formatla.dart';
import '../../../data/datasources/socket_service.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/socket_provider.dart';
import '../../widgets/gun_ayraci.dart';
import '../../widgets/kullanici_avatar.dart';
import '../../widgets/mesaj_balonu.dart';
import '../../widgets/yaziyor_gostergesi.dart';
import 'gorsel_onizleme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? userId;

  const ChatScreen({super.key, required this.conversationId, this.userId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _mesajController = TextEditingController();

  // Belirli bir mesaja kaydirabilmek icin indeksle calisan liste kullaniyoruz;
  // balon yukseklikleri degiskan oldugu icin piksel tahmini guvenilir degildi.
  final _listeKontrol = ItemScrollController();
  final _konumDinleyici = ItemPositionsListener.create();

  UserModel? _karsiTaraf;
  bool _karsiTarafYukleniyor = true;
  Timer? _yaziyorZamanlayici;
  bool _yaziyorGonderildi = false;

  // Indirilmekte olan eklerin mesaj id'leri
  final Set<String> _indirilenler = {};

  // Arama durumu
  bool _aramaAcik = false;
  final _aramaController = TextEditingController();
  Timer? _aramaDebounce;
  List<String> _eslesmeler = [];
  int _aktifEslesme = 0;
  bool _aramaYukleniyor = false;
  String? _vurgulananId;

  // dispose sirasinda ref kullanilamadigi icin servisi burada tutuyoruz
  late final SocketService _socketServis;

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

    _socketServis = ref.read(socketServiceProvider);
    _konumDinleyici.itemPositions.addListener(_konumDegisti);
    _mesajController.addListener(_yazmaDinle);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _karsiTarafiYukle();

      if (!_yeniSohbet) {
        _socketServis.sohbeteKatil(widget.conversationId);
        ref.read(mesajProvider(_param).notifier).okunduIsaretle();
        ref.read(sohbetListesiProvider.notifier).okunduIsaretle(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    if (!_yeniSohbet) {
      _socketServis.sohbettenAyril(widget.conversationId);
      if (_yaziyorGonderildi) {
        _socketServis.yaziyorBitir(widget.conversationId);
      }
    }

    _yaziyorZamanlayici?.cancel();
    _aramaDebounce?.cancel();
    _mesajController.removeListener(_yazmaDinle);
    _konumDinleyici.itemPositions.removeListener(_konumDegisti);
    _aramaController.dispose();
    _mesajController.dispose();
    super.dispose();
  }

  // Liste ters oldugu icin buyuk indeksler eski mesajlar demek.
  // Listenin sonuna yaklasinca bir sonraki sayfayi yukluyoruz.
  void _konumDegisti() {
    final konumlar = _konumDinleyici.itemPositions.value;
    if (konumlar.isEmpty) return;

    final enBuyukIndeks = konumlar.map((k) => k.index).reduce((a, b) => a > b ? a : b);
    final toplam = ref.read(mesajProvider(_param)).mesajlar.length;

    if (toplam > 0 && enBuyukIndeks >= toplam - 3) {
      ref.read(mesajProvider(_param).notifier).eskileriYukle();
    }
  }

  // Kullanici yazarken karsi tarafa bildirim gonderir
  void _yazmaDinle() {
    if (_yeniSohbet) return;

    final bosMu = _mesajController.text.trim().isEmpty;

    if (bosMu) {
      if (_yaziyorGonderildi) {
        _socketServis.yaziyorBitir(widget.conversationId);
        _yaziyorGonderildi = false;
      }
      _yaziyorZamanlayici?.cancel();
      return;
    }

    if (!_yaziyorGonderildi) {
      _socketServis.yaziyorBaslat(widget.conversationId);
      _yaziyorGonderildi = true;
    }

    // Yazmayi birakirsa 2 saniye sonra durdur
    _yaziyorZamanlayici?.cancel();
    _yaziyorZamanlayici = Timer(const Duration(seconds: 2), () {
      if (_yaziyorGonderildi) {
        _socketServis.yaziyorBitir(widget.conversationId);
        _yaziyorGonderildi = false;
      }
    });
  }

  Future<void> _karsiTarafiYukle() async {
    try {
      if (_yeniSohbet && widget.userId != null) {
        final kullanici =
            await ref.read(userRepositoryProvider).kullaniciGetir(widget.userId!);
        if (mounted) setState(() => _karsiTaraf = kullanici);
      } else {
        final detay =
            await ref.read(chatRepositoryProvider).sohbetDetay(widget.conversationId);
        if (mounted) setState(() => _karsiTaraf = detay);
      }
    } catch (_) {
      // Karsi taraf yuklenemezse baslikta varsayilan metin gosterilir
    } finally {
      if (mounted) setState(() => _karsiTarafYukleniyor = false);
    }
  }

  Future<void> _gonder() async {
    final icerik = _mesajController.text.trim();
    if (icerik.isEmpty) return;

    _mesajController.clear();

    if (_yaziyorGonderildi) {
      _socketServis.yaziyorBitir(widget.conversationId);
      _yaziyorGonderildi = false;
    }
    _yaziyorZamanlayici?.cancel();

    final notifier = ref.read(mesajProvider(_param).notifier);
    await notifier.mesajGonder(icerik);

    ref.read(sohbetListesiProvider.notifier).tazele();

    if (_sohbetOlustuysaTasi(notifier)) return;

    _enAltaKaydir();
  }

  /// Ilk mesajla sohbet olustuysa ekrani gercek sohbet id'sine tasir.
  /// Aksi halde ekran "yeni" anahtariyla acik kalir: socket olaylari farkli
  /// anahtarla geldigi icin bu ekrana ulasmaz, sohbet odasina da katilinmaz.
  bool _sohbetOlustuysaTasi(MesajNotifier notifier) {
    final olusanId = notifier.olusanSohbetId;

    if (_yeniSohbet && olusanId != null && mounted) {
      context.replace('${Rotalar.chat}/$olusanId');
      return true;
    }

    return false;
  }

  void _enAltaKaydir() {
    if (!_listeKontrol.isAttached) return;

    _listeKontrol.scrollTo(
      index: 0,
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

  void _uyari(String mesaj) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: AppColors.error),
    );
  }

  // Ataç menusu: galeri, kamera, dosya.
  // Yeni sohbette de calisir; sohbet ilk ek ile birlikte olusur.
  void _ekMenusu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Galeriden sec'),
              onTap: () {
                Navigator.pop(context);
                _gorselSec(galeriden: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Fotograf cek'),
              onTap: () {
                Navigator.pop(context);
                _gorselSec(galeriden: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: AppColors.primary),
              title: const Text('Dosya gonder'),
              onTap: () {
                Navigator.pop(context);
                _dosyaSec();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Yazi alanindaki metin varsa ekin aciklamasi olarak gonderilir
  String? _aciklamaAl() {
    final metin = _mesajController.text.trim();
    if (metin.isEmpty) return null;

    _mesajController.clear();
    return metin;
  }

  Future<void> _gorselSec({required bool galeriden}) async {
    try {
      final yol = galeriden
          ? await MedyaSecici.galeriden()
          : await MedyaSecici.kameradan();

      if (yol == null || !mounted) return;

      final notifier = ref.read(mesajProvider(_param).notifier);
      await notifier.gorselGonder(yol, icerik: _aciklamaAl());

      if (!mounted) return;
      ref.read(sohbetListesiProvider.notifier).tazele();

      if (_sohbetOlustuysaTasi(notifier)) return;
      _enAltaKaydir();
    } catch (_) {
      _uyari('Gorsel secilemedi');
    }
  }

  Future<void> _dosyaSec() async {
    try {
      final dosya = await MedyaSecici.dosya();
      if (dosya == null || !mounted) return;

      final notifier = ref.read(mesajProvider(_param).notifier);
      await notifier.dosyaGonder(
        dosya.yol,
        dosyaAdi: dosya.ad,
        boyut: dosya.boyut,
        icerik: _aciklamaAl(),
      );

      if (!mounted) return;
      ref.read(sohbetListesiProvider.notifier).tazele();

      if (_sohbetOlustuysaTasi(notifier)) return;
      _enAltaKaydir();
    } catch (_) {
      _uyari('Dosya secilemedi');
    }
  }

  // Gorsele dokununca tam ekran, dosyaya dokununca indirip acar
  Future<void> _ekAc(MessageModel mesaj) async {
    final ek = mesaj.attachments.isNotEmpty ? mesaj.attachments.first : null;

    if (mesaj.type == MesajTipi.image) {
      if (ek == null && mesaj.yerelDosyaYolu == null) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GorselOnizleme(
            url: ek?.url,
            yerelYol: mesaj.yerelDosyaYolu,
            baslik: mesaj.senderId == ref.read(authProvider).kullanici?.id
                ? 'Sen'
                : (_karsiTaraf?.fullName ?? 'Gorsel'),
            tarih: mesaj.createdAt,
          ),
        ),
      );
      return;
    }

    // Henuz gonderilmemis dosya cihazda zaten duruyor
    if (ek == null || ek.url.isEmpty) return;
    if (_indirilenler.contains(mesaj.id)) return;

    setState(() => _indirilenler.add(mesaj.id));

    try {
      final yol = await ref.read(dosyaIndiriciProvider).indir(
            url: ek.url,
            dosyaAdi: ek.fileName ?? 'dosya',
            mesajId: mesaj.id,
          );

      final hata = await ref.read(dosyaIndiriciProvider).ac(yol);
      if (hata != null) _uyari(hata);
    } catch (_) {
      _uyari('Dosya indirilemedi, baglantini kontrol et');
    } finally {
      if (mounted) setState(() => _indirilenler.remove(mesaj.id));
    }
  }

  // --- Sohbet ici arama ---------------------------------------------------

  void _aramayiAc() {
    setState(() => _aramaAcik = true);
  }

  void _aramayiKapat() {
    _aramaDebounce?.cancel();
    _aramaController.clear();

    setState(() {
      _aramaAcik = false;
      _eslesmeler = [];
      _aktifEslesme = 0;
      _aramaYukleniyor = false;
      _vurgulananId = null;
    });
  }

  void _aramaTerimiDegisti(String terim) {
    _aramaDebounce?.cancel();

    if (terim.trim().length < 2) {
      setState(() {
        _eslesmeler = [];
        _aktifEslesme = 0;
        _vurgulananId = null;
      });
      return;
    }

    _aramaDebounce = Timer(const Duration(milliseconds: 400), () => _ara(terim.trim()));
  }

  Future<void> _ara(String terim) async {
    setState(() => _aramaYukleniyor = true);

    try {
      final sonuclar =
          await ref.read(chatRepositoryProvider).mesajAra(widget.conversationId, terim);

      if (!mounted) return;

      setState(() {
        // Sunucu yeniden eskiye siralar; ilk eslesme en yeni mesaj olur
        _eslesmeler = sonuclar.map((m) => m.id).toList();
        _aktifEslesme = 0;
      });

      if (_eslesmeler.isNotEmpty) {
        await _eslesmeyeGit(0);
      } else {
        setState(() => _vurgulananId = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _eslesmeler = [];
        _aktifEslesme = 0;
      });
      _uyari('Arama yapilamadi');
    } finally {
      if (mounted) setState(() => _aramaYukleniyor = false);
    }
  }

  // Yukari tusu daha eskiye, asagi tusu daha yeniye gider
  Future<void> _eslesmeDegistir(int yon) async {
    if (_eslesmeler.isEmpty) return;

    final yeni = _aktifEslesme + yon;
    if (yeni < 0 || yeni >= _eslesmeler.length) return;

    await _eslesmeyeGit(yeni);
  }

  Future<void> _eslesmeyeGit(int sira) async {
    final mesajId = _eslesmeler[sira];
    final notifier = ref.read(mesajProvider(_param).notifier);

    // Mesaj henuz yuklenmemis olabilir; bulunana kadar eski sayfalar cekilir
    final bulundu = await notifier.mesajaKadarYukle(mesajId);
    if (!mounted) return;

    if (!bulundu) {
      _uyari('Mesaj yuklenemedi');
      return;
    }

    final indeks =
        ref.read(mesajProvider(_param)).mesajlar.indexWhere((m) => m.id == mesajId);

    setState(() {
      _aktifEslesme = sira;
      _vurgulananId = mesajId;
    });

    if (indeks >= 0 && _listeKontrol.isAttached) {
      _listeKontrol.scrollTo(
        index: indeks,
        alignment: 0.35,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // Arama acikken baslik yerine metin alani gosterilir
  PreferredSizeWidget _aramaBasligi() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _aramayiKapat,
      ),
      titleSpacing: 0,
      title: TextField(
        controller: _aramaController,
        autofocus: true,
        onChanged: _aramaTerimiDegisti,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Bu sohbette ara',
          border: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        if (_aramaController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _aramaController.clear();
              _aramaTerimiDegisti('');
            },
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: _eslesmeCubugu(),
      ),
    );
  }

  Widget _eslesmeCubugu() {
    final terimVar = _aramaController.text.trim().length >= 2;
    final toplam = _eslesmeler.length;

    String metin;
    if (_aramaYukleniyor) {
      metin = 'Araniyor...';
    } else if (!terimVar) {
      metin = 'En az 2 karakter yaz';
    } else if (toplam == 0) {
      metin = 'Sonuc bulunamadi';
    } else {
      metin = '${_aktifEslesme + 1}/$toplam';
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            metin,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: toplam == 0 && terimVar && !_aramaYukleniyor
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: 'Onceki (daha eski)',
            visualDensity: VisualDensity.compact,
            color: AppColors.primary,
            onPressed: _aktifEslesme < toplam - 1 ? () => _eslesmeDegistir(1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: 'Sonraki (daha yeni)',
            visualDensity: VisualDensity.compact,
            color: AppColors.primary,
            onPressed: _aktifEslesme > 0 ? () => _eslesmeDegistir(-1) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durum = ref.watch(mesajProvider(_param));
    final benimId = ref.watch(authProvider).kullanici?.id ?? '';
    final yaziyor = ref.watch(yaziyorProvider)[widget.conversationId] ?? false;

    // Sohbet ekrani acikken gelen mesajlar hemen okundu isaretlenir
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
      appBar: _aramaAcik ? _aramaBasligi() : _baslik(yaziyor),
      body: Column(
        children: [
          Expanded(child: _mesajListesi(durum, benimId)),
          // Arama acikken yazma alani gizlenir, ekran aramaya odaklanir
          if (!_aramaAcik) ...[
            if (yaziyor) const YaziyorGostergesi(),
            _girisAlani(),
          ],
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
      actions: [
        if (!_yeniSohbet)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Sohbette ara',
            onPressed: _aramayiAc,
          ),
      ],
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

    return ScrollablePositionedList.builder(
      itemScrollController: _listeKontrol,
      itemPositionsListener: _konumDinleyici,
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
        final vurgulu = mesaj.id == _vurgulananId;

        // Bir sonraki (daha eski) mesaj farkli gunde ise ayrac koy
        final sonraki = index + 1 < durum.mesajlar.length ? durum.mesajlar[index + 1] : null;
        final gunDegisti = sonraki == null || !_ayniGun(mesaj.createdAt, sonraki.createdAt);

        return Column(
          children: [
            MesajBalonu(
              mesaj: mesaj,
              benimMi: benimMi,
              vurgulu: vurgulu,
              indiriliyor: _indirilenler.contains(mesaj.id),
              onUzunBas: () => _mesajMenusu(mesaj),
              onEkAc: () => _ekAc(mesaj),
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
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              tooltip: 'Ek gonder',
              onPressed: _ekMenusu,
            ),
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