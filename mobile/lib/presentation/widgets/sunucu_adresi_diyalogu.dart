import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/socket_provider.dart';

/// Sunucu adresini uygulama icinden degistirir.
///
/// Adres yalnizca derlemeye gomulseydi, teslim edilen APK derleyenin yerel
/// IP'sine bagli kalirdi; ag degistiginde ya da uygulamayi baska biri
/// calistirdiginda yeniden derlemek gerekirdi.
class SunucuAdresiDiyalogu extends ConsumerStatefulWidget {
  const SunucuAdresiDiyalogu({super.key});

  /// Diyalogu acar; adres degistiyse true doner.
  static Future<bool> ac(BuildContext context) async {
    final sonuc = await showDialog<bool>(
      context: context,
      builder: (context) => const SunucuAdresiDiyalogu(),
    );

    return sonuc ?? false;
  }

  @override
  ConsumerState<SunucuAdresiDiyalogu> createState() => _SunucuAdresiDiyaloguState();
}

class _SunucuAdresiDiyaloguState extends ConsumerState<SunucuAdresiDiyalogu> {
  late final TextEditingController _controller;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: AppConfig.sunucuKoku);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final girdi = _controller.text;
    final hata = AppConfig.adresHatasi(girdi);

    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }

    await AppConfig.sunucuAdresiAyarla(girdi);

    // dio adresi kurulumda aldigi icin elle guncelleniyor, socket de
    // yeni adrese baglanmali
    ref.read(apiClientProvider).adresYenile();

    // Socket eski adrese bagliydi; kapatip yeni adrese yonlendiriyoruz
    final socket = ref.read(socketServiceProvider);
    socket.kopar();
    await socket.baglan();

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sunucu adresi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uygulamanın bağlanacağı sunucunun adresi. Sunucunun çalıştığı '
            'bilgisayarın yerel ağ adresini yazın.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Adres',
              hintText: '192.168.1.5:5000',
              errorText: _hata,
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
            onChanged: (_) {
              if (_hata != null) setState(() => _hata = null);
            },
            onSubmitted: (_) => _kaydet(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Port yazılmazsa 5000 kullanılır.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _kaydet, child: const Text('Kaydet')),
      ],
    );
  }
}
