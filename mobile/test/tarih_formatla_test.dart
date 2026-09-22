import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:chat_app/core/utils/tarih_formatla.dart';

void main() {
  setUpAll(() async {
    // Gun ve ay adlari Turkce bicimlendiriliyor, yerel veriler yuklenmeli
    await initializeDateFormatting('tr');
  });

  group('sohbet listesi zamani', () {
    test('tarih yoksa bos metin doner', () {
      expect(TarihFormat.sohbetListesi(null), '');
    });

    test('bugunku mesajda saat gosterilir', () {
      final tarih = DateTime.now().subtract(const Duration(minutes: 5));

      expect(TarihFormat.sohbetListesi(tarih), matches(r'^\d{2}:\d{2}$'));
    });

    test('dunku mesajda gun adi yerine Dun yazar', () {
      final tarih = DateTime.now().subtract(const Duration(days: 1));

      expect(TarihFormat.sohbetListesi(tarih), 'Dun');
    });

    test('bir haftadan eski mesajda tam tarih gosterilir', () {
      final tarih = DateTime.now().subtract(const Duration(days: 10));

      expect(TarihFormat.sohbetListesi(tarih), matches(r'^\d{2}\.\d{2}\.\d{4}$'));
    });
  });

  group('gun ayraci', () {
    test('bugun ve dun icin metin doner', () {
      expect(TarihFormat.gunAyraci(DateTime.now()), 'Bugun');
      expect(
        TarihFormat.gunAyraci(DateTime.now().subtract(const Duration(days: 1))),
        'Dun',
      );
    });

    test('daha eski tarihte gun ve ay adi yazilir', () {
      final tarih = DateTime(2026, 3, 15);

      expect(TarihFormat.gunAyraci(tarih), '15 Mart 2026');
    });
  });

  group('son gorulme', () {
    test('tarih yoksa bos metin doner', () {
      expect(TarihFormat.sonGorulme(null), '');
    });

    test('bir dakikadan yeni ise az once yazar', () {
      expect(TarihFormat.sonGorulme(DateTime.now()), 'az once');
    });

    test('bir saat icinde dakika olarak yazar', () {
      final tarih = DateTime.now().subtract(const Duration(minutes: 30, seconds: 1));

      expect(TarihFormat.sonGorulme(tarih), '30 dakika once');
    });

    test('dun goruldu ise saatiyle birlikte yazar', () {
      final tarih = DateTime.now().subtract(const Duration(days: 1));

      expect(TarihFormat.sonGorulme(tarih), matches(r'^dun \d{2}:\d{2}$'));
    });
  });

  test('mesaj saati her zaman saat:dakika bicimindedir', () {
    expect(TarihFormat.mesajSaati(DateTime(2026, 1, 1, 9, 5)), '09:05');
  });
}
