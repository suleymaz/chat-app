import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'chat_provider.dart';

const _uuid = Uuid();

class MesajDurum {
  final List<MessageModel> mesajlar;
  final bool yukleniyor;
  final bool dahaVar;
  final bool eskiYukleniyor;
  final String? hata;
  final String? cursor;

  MesajDurum({
    this.mesajlar = const [],
    this.yukleniyor = true,
    this.dahaVar = false,
    this.eskiYukleniyor = false,
    this.hata,
    this.cursor,
  });

  MesajDurum copyWith({
    List<MessageModel>? mesajlar,
    bool? yukleniyor,
    bool? dahaVar,
    bool? eskiYukleniyor,
    String? hata,
    String? cursor,
    bool hatayiTemizle = false,
  }) {
    return MesajDurum(
      mesajlar: mesajlar ?? this.mesajlar,
      yukleniyor: yukleniyor ?? this.yukleniyor,
      dahaVar: dahaVar ?? this.dahaVar,
      eskiYukleniyor: eskiYukleniyor ?? this.eskiYukleniyor,
      hata: hatayiTemizle ? null : (hata ?? this.hata),
      cursor: cursor ?? this.cursor,
    );
  }
}

class MesajNotifier extends StateNotifier<MesajDurum> {
  final ChatRepository _repo;
  final String? conversationId;
  final String? karsiTarafId;
  final String benimId;

  // Yeni sohbet ilk mesajla olustugunda id buraya yazilir
  String? olusanSohbetId;

  // Mesaj listeye yerlesmeden once gelen iletildi bilgileri burada bekler
  final Map<String, DateTime> _bekleyenIletildi = {};

  // Repo konumsal parametre: adlandirilmis parametreler private alana
  // dogrudan atanamiyor, ara degisken kullanmak yerine boyle aliyoruz.
  MesajNotifier(
    this._repo, {
    required this.conversationId,
    required this.karsiTarafId,
    required this.benimId,
  }) : super(MesajDurum()) {
    if (conversationId != null) {
      ilkYukleme();
    } else {
      // Yeni sohbet - yuklenecek mesaj yok
      state = MesajDurum(yukleniyor: false);
    }
  }

  String get _aktifSohbetId => conversationId ?? olusanSohbetId ?? '';

  Future<void> ilkYukleme() async {
    state = state.copyWith(yukleniyor: true, hatayiTemizle: true);

    try {
      final sayfa = await _repo.mesajlariGetir(_aktifSohbetId);

      state = MesajDurum(
        mesajlar: sayfa.mesajlar,
        yukleniyor: false,
        dahaVar: sayfa.hasMore,
        cursor: sayfa.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(yukleniyor: false, hata: 'Mesajlar yuklenemedi');
    }
  }

  // Yukari kaydirinca eski mesajlari getirir
  Future<void> eskileriYukle() async {
    if (!state.dahaVar || state.eskiYukleniyor || state.cursor == null) return;

    state = state.copyWith(eskiYukleniyor: true);

    try {
      final sayfa = await _repo.mesajlariGetir(_aktifSohbetId, cursor: state.cursor);

      state = state.copyWith(
        mesajlar: [...state.mesajlar, ...sayfa.mesajlar],
        dahaVar: sayfa.hasMore,
        cursor: sayfa.nextCursor,
        eskiYukleniyor: false,
      );
    } catch (_) {
      state = state.copyWith(eskiYukleniyor: false);
    }
  }

  // Optimistic gonderim - mesaj once ekranda gorunur, sonra sunucuya gider
  Future<void> mesajGonder(String icerik) async {
    final geciciId = _uuid.v4();

    final geciciMesaj = MessageModel(
      id: geciciId,
      conversationId: _aktifSohbetId,
      senderId: benimId,
      content: icerik,
      createdAt: DateTime.now(),
      yerelDurum: MesajDurumu.gonderiliyor,
    );

    state = state.copyWith(mesajlar: [geciciMesaj, ...state.mesajlar]);

    try {
      MessageModel gercekMesaj;

      if (_aktifSohbetId.isEmpty) {
        // Ilk mesaj - sohbet de burada olusuyor
        final sonuc = await _repo.yeniSohbetBaslat(
          userId: karsiTarafId!,
          icerik: icerik,
        );
        olusanSohbetId = sonuc.conversationId;
        gercekMesaj = sonuc.message;
      } else {
        gercekMesaj = await _repo.mesajGonder(_aktifSohbetId, icerik);
      }

      _mesajiDegistir(geciciId, gercekMesaj);
    } catch (_) {
      _durumGuncelle(geciciId, MesajDurumu.basarisiz);
    }
  }

  // Galeriden/kameradan secilen gorseli gonderir.
  // Gorsel once cihazdaki dosyadan gosterilir, sunucu yanitiyla degistirilir.
  Future<void> gorselGonder(String dosyaYolu, {String? icerik}) async {
    final geciciId = _uuid.v4();

    _geciciEkle(
      MessageModel(
        id: geciciId,
        conversationId: _aktifSohbetId,
        senderId: benimId,
        content: icerik,
        type: MesajTipi.image,
        createdAt: DateTime.now(),
        yerelDurum: MesajDurumu.gonderiliyor,
        yerelDosyaYolu: dosyaYolu,
      ),
    );

    try {
      MessageModel gercek;

      if (_aktifSohbetId.isEmpty) {
        // Ilk mesaj gorsel: sohbet de bu istekte olusuyor
        final sonuc = await _repo.yeniSohbetGorselGonder(
          userId: karsiTarafId!,
          dosyaYolu: dosyaYolu,
          icerik: icerik,
        );
        olusanSohbetId = sonuc.conversationId;
        gercek = sonuc.message;
      } else {
        gercek = await _repo.gorselGonder(_aktifSohbetId, dosyaYolu, icerik: icerik);
      }

      _mesajiDegistir(geciciId, gercek);
    } catch (_) {
      _durumGuncelle(geciciId, MesajDurumu.basarisiz);
    }
  }

  // Secilen dosyayi gonderir. Yuklenirken balonda ad ve boyut gorunur.
  Future<void> dosyaGonder(
    String dosyaYolu, {
    required String dosyaAdi,
    required int boyut,
    String? icerik,
  }) async {
    final geciciId = _uuid.v4();

    _geciciEkle(
      MessageModel(
        id: geciciId,
        conversationId: _aktifSohbetId,
        senderId: benimId,
        content: icerik,
        type: MesajTipi.file,
        createdAt: DateTime.now(),
        yerelDurum: MesajDurumu.gonderiliyor,
        yerelDosyaYolu: dosyaYolu,
        attachments: [
          AttachmentModel(
            id: geciciId,
            url: '',
            fileName: dosyaAdi,
            mimeType: '',
            sizeBytes: boyut,
          ),
        ],
      ),
    );

    try {
      MessageModel gercek;

      if (_aktifSohbetId.isEmpty) {
        // Ilk mesaj dosya: sohbet de bu istekte olusuyor
        final sonuc = await _repo.yeniSohbetDosyaGonder(
          userId: karsiTarafId!,
          dosyaYolu: dosyaYolu,
          dosyaAdi: dosyaAdi,
          icerik: icerik,
        );
        olusanSohbetId = sonuc.conversationId;
        gercek = sonuc.message;
      } else {
        gercek = await _repo.dosyaGonder(
          _aktifSohbetId,
          dosyaYolu,
          icerik: icerik,
          dosyaAdi: dosyaAdi,
        );
      }

      _mesajiDegistir(geciciId, gercek);
    } catch (_) {
      _durumGuncelle(geciciId, MesajDurumu.basarisiz);
    }
  }

  void _geciciEkle(MessageModel mesaj) {
    state = state.copyWith(mesajlar: [mesaj, ...state.mesajlar]);
  }

  // Basarisiz mesaji tekrar gonderir - metin, gorsel ve dosya icin
  Future<void> tekrarGonder(String mesajId) async {
    final mesaj = state.mesajlar.firstWhere((m) => m.id == mesajId);
    final icerik = mesaj.content ?? '';

    _durumGuncelle(mesajId, MesajDurumu.gonderiliyor);

    try {
      MessageModel gercekMesaj;

      if (mesaj.yerelDosyaYolu != null) {
        final dosyaAdi = mesaj.attachments.firstOrNull?.fileName;

        if (mesaj.type == MesajTipi.image) {
          if (_aktifSohbetId.isEmpty) {
            final sonuc = await _repo.yeniSohbetGorselGonder(
              userId: karsiTarafId!,
              dosyaYolu: mesaj.yerelDosyaYolu!,
              icerik: mesaj.content,
            );
            olusanSohbetId = sonuc.conversationId;
            gercekMesaj = sonuc.message;
          } else {
            gercekMesaj = await _repo.gorselGonder(
              _aktifSohbetId,
              mesaj.yerelDosyaYolu!,
              icerik: mesaj.content,
            );
          }
        } else {
          if (_aktifSohbetId.isEmpty) {
            final sonuc = await _repo.yeniSohbetDosyaGonder(
              userId: karsiTarafId!,
              dosyaYolu: mesaj.yerelDosyaYolu!,
              dosyaAdi: dosyaAdi,
              icerik: mesaj.content,
            );
            olusanSohbetId = sonuc.conversationId;
            gercekMesaj = sonuc.message;
          } else {
            gercekMesaj = await _repo.dosyaGonder(
              _aktifSohbetId,
              mesaj.yerelDosyaYolu!,
              icerik: mesaj.content,
              dosyaAdi: dosyaAdi,
            );
          }
        }
      } else if (_aktifSohbetId.isEmpty) {
        final sonuc = await _repo.yeniSohbetBaslat(userId: karsiTarafId!, icerik: icerik);
        olusanSohbetId = sonuc.conversationId;
        gercekMesaj = sonuc.message;
      } else {
        gercekMesaj = await _repo.mesajGonder(_aktifSohbetId, icerik);
      }

      _mesajiDegistir(mesajId, gercekMesaj);
    } catch (_) {
      _durumGuncelle(mesajId, MesajDurumu.basarisiz);
    }
  }

  /// Aranan mesaj listede yoksa bulunana kadar eski sayfalari yukler.
  /// Cok uzun sohbetlerde sonsuz donguye girmemesi icin sayfa siniri var.
  Future<bool> mesajaKadarYukle(String mesajId) async {
    const maksSayfa = 20;
    var sayfa = 0;

    while (!state.mesajlar.any((m) => m.id == mesajId)) {
      if (!state.dahaVar || state.cursor == null || sayfa >= maksSayfa) return false;

      await eskileriYukle();
      sayfa++;
    }

    return true;
  }

  Future<void> mesajSil(String mesajId) async {
    try {
      final silinmis = await _repo.mesajSil(mesajId);
      _mesajiDegistir(mesajId, silinmis);
    } catch (_) {
      // Silme basarisizsa liste degismez
    }
  }

  // Basarisiz mesaji listeden cikarir
  void mesajiKaldir(String mesajId) {
    state = state.copyWith(
      mesajlar: state.mesajlar.where((m) => m.id != mesajId).toList(),
    );
  }

  Future<void> okunduIsaretle() async {
    if (_aktifSohbetId.isEmpty) return;

    try {
      await _repo.okunduIsaretle(_aktifSohbetId);
    } catch (_) {
      // Sessizce gec
    }
  }

  void _mesajiDegistir(String eskiId, MessageModel yeni) {
    // Bu mesaj icin iletildi bilgisi onceden geldiyse simdi uygula
    final bekleyenTarih = _bekleyenIletildi.remove(yeni.id);
    final guncel = bekleyenTarih != null && yeni.deliveredAt == null
        ? yeni.copyWith(deliveredAt: bekleyenTarih)
        : yeni;

    state = state.copyWith(
      mesajlar: [
        for (final m in state.mesajlar)
          if (m.id == eskiId) guncel else m,
      ],
    );
  }

  void _durumGuncelle(String mesajId, MesajDurumu durum) {
    state = state.copyWith(
      mesajlar: [
        for (final m in state.mesajlar)
          if (m.id == mesajId) m.copyWith(yerelDurum: durum) else m,
      ],
    );
  }

  // Socket'ten gelen yeni mesaji listeye ekler
  void mesajEkle(MessageModel mesaj) {
    // Zaten varsa tekrar ekleme
    if (state.mesajlar.any((m) => m.id == mesaj.id)) return;

    state = state.copyWith(mesajlar: [mesaj, ...state.mesajlar]);
  }

  // Socket'ten gelen iletildi bilgisini isler
  void iletildiIsaretle(List<String> mesajIdleri, DateTime deliveredAt) {
    // Mesaj henuz listeye yerlesmemis olabilir, bilgiyi sakla
    for (final id in mesajIdleri) {
      _bekleyenIletildi[id] = deliveredAt;
    }

    state = state.copyWith(
      mesajlar: [
        for (final m in state.mesajlar)
          if (mesajIdleri.contains(m.id) && m.deliveredAt == null)
            m.copyWith(deliveredAt: deliveredAt)
          else
            m,
      ],
    );
  }

  // Karsi taraf sohbeti actiginda tum mesajlar okundu olur
  void okunduIsaretleYerel(DateTime readAt) {
    state = state.copyWith(
      mesajlar: [
        for (final m in state.mesajlar)
          if (m.senderId == benimId && m.readAt == null)
            m.copyWith(readAt: readAt, deliveredAt: m.deliveredAt ?? readAt)
          else
            m,
      ],
    );
  }

  // Karsi taraf mesajini sildiginde
  void mesajSilindiIsaretle(String mesajId) {
    state = state.copyWith(
      mesajlar: [
        for (final m in state.mesajlar)
          if (m.id == mesajId) m.copyWith(deletedAt: DateTime.now()) else m,
      ],
    );
  }
}

// Her sohbet icin ayri notifier - family kullaniyoruz
final mesajProvider =
    StateNotifierProvider.autoDispose.family<MesajNotifier, MesajDurum, MesajParam>(
  (ref, param) => MesajNotifier(
    ref.watch(chatRepositoryProvider),
    conversationId: param.conversationId,
    karsiTarafId: param.karsiTarafId,
    benimId: param.benimId,
  ),
);

class MesajParam {
  final String? conversationId;
  final String? karsiTarafId;
  final String benimId;

  MesajParam({this.conversationId, this.karsiTarafId, required this.benimId});

  @override
  bool operator ==(Object other) =>
      other is MesajParam &&
      other.conversationId == conversationId &&
      other.karsiTarafId == karsiTarafId;

  @override
  int get hashCode => Object.hash(conversationId, karsiTarafId);
}