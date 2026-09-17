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

  MesajNotifier({
    required ChatRepository repo,
    required this.conversationId,
    required this.karsiTarafId,
    required this.benimId,
  })  : _repo = repo,
        super(MesajDurum()) {
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

  // Basarisiz mesaji tekrar gonderir
  Future<void> tekrarGonder(String mesajId) async {
    final mesaj = state.mesajlar.firstWhere((m) => m.id == mesajId);
    final icerik = mesaj.content ?? '';

    _durumGuncelle(mesajId, MesajDurumu.gonderiliyor);

    try {
      MessageModel gercekMesaj;

      if (_aktifSohbetId.isEmpty) {
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
    repo: ref.watch(chatRepositoryProvider),
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