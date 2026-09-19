import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/hata_kutusu.dart';

/// Sifre degistirme. Sunucu sifre degisince tum oturumlari sonlandirdigi icin
/// islem basarili olunca kullanici cikisa yonlendirilir.
class SifreDegistirEkrani extends ConsumerStatefulWidget {
  const SifreDegistirEkrani({super.key});

  @override
  ConsumerState<SifreDegistirEkrani> createState() => _SifreDegistirEkraniState();
}

class _SifreDegistirEkraniState extends ConsumerState<SifreDegistirEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _mevcutController = TextEditingController();
  final _yeniController = TextEditingController();
  final _tekrarController = TextEditingController();

  bool _kaydediliyor = false;
  String? _genelHata;
  Map<String, String>? _alanHatalari;

  @override
  void dispose() {
    _mevcutController.dispose();
    _yeniController.dispose();
    _tekrarController.dispose();
    super.dispose();
  }

  Future<void> _degistir() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _kaydediliyor = true;
      _genelHata = null;
      _alanHatalari = null;
    });

    try {
      await ref.read(userRepositoryProvider).sifreDegistir(
            currentPassword: _mevcutController.text,
            newPassword: _yeniController.text,
          );

      if (!mounted) return;
      await _basariliUyarisi();
    } on DioException catch (e) {
      final hata = e.error;
      if (!mounted) return;
      setState(() {
        _genelHata = hata is ApiException ? hata.message : 'Sifre degistirilemedi';
        _alanHatalari = hata is ApiException ? hata.alanHatalari : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _genelHata = 'Beklenmeyen bir hata olustu');
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  Future<void> _basariliUyarisi() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sifren degistirildi'),
        content: const Text(
          'Guvenlik icin tum cihazlardaki oturumlar sonlandirildi. '
          'Yeni sifrenle tekrar giris yapman gerekiyor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await ref.read(authProvider.notifier).cikisYap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sifre degistir')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_genelHata != null) ...[
                    HataKutusu(mesaj: _genelHata!),
                    const SizedBox(height: 16),
                  ],

                  AppTextField(
                    controller: _mevcutController,
                    label: 'Mevcut sifre',
                    icon: Icons.lock_outline,
                    sifreMi: true,
                    aktif: !_kaydediliyor,
                    hataMetni: _alanHatalari?['currentPassword'],
                    dogrula: (deger) {
                      if (deger == null || deger.isEmpty) return 'Mevcut sifre gerekli';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _yeniController,
                    label: 'Yeni sifre',
                    icon: Icons.lock_reset_outlined,
                    sifreMi: true,
                    aktif: !_kaydediliyor,
                    hataMetni: _alanHatalari?['newPassword'],
                    dogrula: _yeniSifreDogrula,
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _tekrarController,
                    label: 'Yeni sifre (tekrar)',
                    icon: Icons.lock_reset_outlined,
                    sifreMi: true,
                    aktif: !_kaydediliyor,
                    dogrula: (deger) {
                      if (deger != _yeniController.text) return 'Sifreler eslesmiyor';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Sifre en az 8 karakter olmali; bir buyuk harf, bir kucuk harf '
                    've bir rakam icermeli.',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    metin: 'Sifreyi degistir',
                    yukleniyor: _kaydediliyor,
                    onPressed: _degistir,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Sunucudaki kurallarin ayni si - istek atmadan once burada yakalaniyor
  String? _yeniSifreDogrula(String? deger) {
    final sifre = deger ?? '';

    if (sifre.length < 8) return 'Sifre en az 8 karakter olmali';
    if (!RegExp(r'[a-z]').hasMatch(sifre)) return 'En az bir kucuk harf icermeli';
    if (!RegExp(r'[A-Z]').hasMatch(sifre)) return 'En az bir buyuk harf icermeli';
    if (!RegExp(r'[0-9]').hasMatch(sifre)) return 'En az bir rakam icermeli';
    if (sifre == _mevcutController.text) return 'Yeni sifre eskisiyle ayni olamaz';

    return null;
  }
}
