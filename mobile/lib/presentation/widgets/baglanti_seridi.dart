import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers/socket_provider.dart';

/// Sunucu baglantisi koptugunda ekranin ustunde beliren uyari seridi.
///
/// Serit gecikmeli gosteriliyor: socket kisa sureligine kopup hemen geri
/// baglandiginda (ag degisimi, uygulamanin one gelmesi) serit bir anlik
/// gorunup kaybolsaydi ekran surekli oynardi. Baglanti geri geldiginde ise
/// bekletmeden kaldiriliyor.
///
/// Baslangicta socket henuz hicbir olay yayinlamadigi icin durum bilinmiyor;
/// o sirada serit gosterilmiyor, aksi halde uygulama her acilista kirmizi bir
/// seritle karsilardi.
class BaglantiSeridi extends ConsumerStatefulWidget {
  const BaglantiSeridi({super.key});

  @override
  ConsumerState<BaglantiSeridi> createState() => _BaglantiSeridiState();
}

class _BaglantiSeridiState extends ConsumerState<BaglantiSeridi> {
  static const _gosterimGecikmesi = Duration(seconds: 2);

  Timer? _zamanlayici;
  bool _gorunsun = false;

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  void _baglantiDegisti(bool bagli) {
    _zamanlayici?.cancel();

    if (bagli) {
      if (_gorunsun) setState(() => _gorunsun = false);
      return;
    }

    if (_gorunsun) return;

    _zamanlayici = Timer(_gosterimGecikmesi, () {
      if (mounted) setState(() => _gorunsun = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(socketBagliProvider, (_, simdiki) {
      final bagli = simdiki.valueOrNull;
      if (bagli != null) _baglantiDegisti(bagli);
    });

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: _gorunsun ? _serit() : const SizedBox(width: double.infinity),
    );
  }

  Widget _serit() {
    return Material(
      color: AppColors.error,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Bağlantı yok, yeniden deneniyor…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
