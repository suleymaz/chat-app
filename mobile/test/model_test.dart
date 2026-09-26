import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/config/app_config.dart';
import 'package:chat_app/data/models/conversation_model.dart';
import 'package:chat_app/data/models/message_model.dart';
import 'package:chat_app/data/models/user_model.dart';

MessageModel mesaj({
  String? content,
  MesajTipi tip = MesajTipi.text,
  DateTime? deliveredAt,
  DateTime? readAt,
  DateTime? deletedAt,
  List<AttachmentModel> ekler = const [],
}) {
  return MessageModel(
    id: 'm1',
    conversationId: 's1',
    senderId: 'k1',
    content: content,
    type: tip,
    deliveredAt: deliveredAt,
    readAt: readAt,
    deletedAt: deletedAt,
    createdAt: DateTime(2026, 1, 1, 12),
    attachments: ekler,
  );
}

void main() {
  group('medya adresi', () {
    // Sunucu goreli yol donuyor; adres degistiginde eski kayitlarin bozulmamasi
    // icin tam adres istemcide birlestiriliyor.
    test('goreli yol sunucu koku ile birlestirilir', () {
      final adres = AppConfig.medyaUrl('/uploads/messages/a.jpg');

      expect(adres, '${AppConfig.sunucuKoku}/uploads/messages/a.jpg');
      expect(adres.contains('/api/v1'), isFalse);
    });

    test('bas taki egik cizgi olmayan yol da birlestirilir', () {
      expect(
        AppConfig.medyaUrl('uploads/a.jpg'),
        '${AppConfig.sunucuKoku}/uploads/a.jpg',
      );
    });

    test('mutlak adres ve bos deger oldugu gibi doner', () {
      expect(AppConfig.medyaUrl('http://sunucu/a.jpg'), 'http://sunucu/a.jpg');
      expect(AppConfig.medyaUrl(''), '');
    });
  });

  group('socket adresi', () {
    // SOCKET_URL verilmediginde API adresinden turetiliyor: iki adresi ayri
    // ayri yazmak, birinde yazim hatasi olunca HTTP calisirken socket'in
    // sessizce baglanamamasina yol aciyordu.
    test('API adresinden turetiliyor ve surum onekini tasimiyor', () {
      expect(AppConfig.socketUrl, AppConfig.sunucuKoku);
      expect(AppConfig.socketUrl.contains('/api/v'), isFalse);
    });

    test('API adresiyle ayni sunucuyu gosteriyor', () {
      expect(AppConfig.apiUrl.startsWith(AppConfig.socketUrl), isTrue);
    });
  });

  group('mesaj durumu', () {
    test('okundu, iletildi ve gonderildi sirasiyla belirlenir', () {
      expect(mesaj(readAt: DateTime.now(), deliveredAt: DateTime.now()).durum,
          MesajDurumu.okundu);
      expect(mesaj(deliveredAt: DateTime.now()).durum, MesajDurumu.iletildi);
      expect(mesaj().durum, MesajDurumu.gonderildi);
    });

    test('yerel durum sunucudan gelen bilgiyi gecersiz kilar', () {
      final bekleyen = MessageModel(
        id: 'm2',
        conversationId: 's1',
        senderId: 'k1',
        createdAt: DateTime.now(),
        readAt: DateTime.now(),
        yerelDurum: MesajDurumu.gonderiliyor,
      );

      expect(bekleyen.durum, MesajDurumu.gonderiliyor);
    });

    test('silinen mesaj isaretlenir', () {
      expect(mesaj(deletedAt: DateTime.now()).silinmis, isTrue);
      expect(mesaj().silinmis, isFalse);
    });
  });

  group('son mesaj ozeti', () {
    ConversationModel sohbet(MessageModel? sonMesaj) {
      return ConversationModel(
        id: 's1',
        user: UserModel(id: 'k2', username: 'ayse', fullName: 'Ayse Yilmaz'),
        lastMessage: sonMesaj,
      );
    }

    test('metin mesajinda icerik gosterilir', () {
      expect(sohbet(mesaj(content: 'merhaba')).sonMesajOzeti, 'merhaba');
    });

    test('gorsel ve dosya icin aciklayici metin gosterilir', () {
      expect(sohbet(mesaj(tip: MesajTipi.image)).sonMesajOzeti, 'Fotograf');

      final dosyaliMesaj = mesaj(
        tip: MesajTipi.file,
        ekler: [
          AttachmentModel(id: 'e1', url: '/uploads/a.pdf', fileName: 'rapor.pdf',
              mimeType: 'application/pdf', sizeBytes: 1024),
        ],
      );

      expect(sohbet(dosyaliMesaj).sonMesajOzeti, 'rapor.pdf');
    });

    test('silinen mesajda uyari metni gosterilir', () {
      expect(
        sohbet(mesaj(content: 'gizli', deletedAt: DateTime.now())).sonMesajOzeti,
        'Bu mesaj silindi',
      );
    });

    test('mesaj yoksa bos metin doner', () {
      expect(sohbet(null).sonMesajOzeti, '');
    });
  });

  group('avatar bas harfleri', () {
    String harfler(String adSoyad) =>
        UserModel(id: 'k1', username: 'k', fullName: adSoyad).basHarfler;

    test('ad ve soyadin bas harfleri alinir', () {
      expect(harfler('Ayse Yilmaz'), 'AY');
      expect(harfler('Mehmet Ali Kaya'), 'MK');
    });

    test('tek kelimede ilk harf kullanilir', () {
      expect(harfler('Ayse'), 'A');
    });

    test('fazladan bosluklar sorun cikarmaz', () {
      expect(harfler('  Ayse   Yilmaz  '), 'AY');
    });
  });

  group('okunur dosya boyutu', () {
    String boyut(int bayt) => AttachmentModel(
          id: 'e1',
          url: '/uploads/a',
          mimeType: 'application/pdf',
          sizeBytes: bayt,
        ).okunurBoyut;

    test('bayt, kilobayt ve megabayt olarak yazilir', () {
      expect(boyut(512), '512 B');
      expect(boyut(2048), '2 KB');
      expect(boyut(3 * 1024 * 1024), '3.0 MB');
    });
  });
}
