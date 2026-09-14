import 'package:intl/intl.dart';

class TarihFormat {
  // Sohbet listesinde gosterilen kisa zaman
  static String sohbetListesi(DateTime? tarih) {
    if (tarih == null) return '';

    final simdi = DateTime.now();
    final yerel = tarih.toLocal();
    final fark = simdi.difference(yerel);

    if (_ayniGun(yerel, simdi)) {
      return DateFormat('HH:mm').format(yerel);
    }

    if (fark.inDays < 2 && _ayniGun(yerel, simdi.subtract(const Duration(days: 1)))) {
      return 'Dun';
    }

    if (fark.inDays < 7) {
      return DateFormat('EEEE', 'tr').format(yerel);
    }

    return DateFormat('dd.MM.yyyy').format(yerel);
  }

  // Mesaj balonundaki saat
  static String mesajSaati(DateTime tarih) {
    return DateFormat('HH:mm').format(tarih.toLocal());
  }

  // Mesaj listesindeki gun ayraci
  static String gunAyraci(DateTime tarih) {
    final simdi = DateTime.now();
    final yerel = tarih.toLocal();

    if (_ayniGun(yerel, simdi)) return 'Bugun';
    if (_ayniGun(yerel, simdi.subtract(const Duration(days: 1)))) return 'Dun';

    return DateFormat('d MMMM yyyy', 'tr').format(yerel);
  }

  // Son gorulme bilgisi
  static String sonGorulme(DateTime? tarih) {
    if (tarih == null) return '';

    final simdi = DateTime.now();
    final yerel = tarih.toLocal();
    final fark = simdi.difference(yerel);

    if (fark.inMinutes < 1) return 'az once';
    if (fark.inMinutes < 60) return '${fark.inMinutes} dakika once';
    if (_ayniGun(yerel, simdi)) return 'bugun ${DateFormat('HH:mm').format(yerel)}';
    if (_ayniGun(yerel, simdi.subtract(const Duration(days: 1)))) {
      return 'dun ${DateFormat('HH:mm').format(yerel)}';
    }

    return DateFormat('dd.MM.yyyy HH:mm').format(yerel);
  }

  static bool _ayniGun(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}