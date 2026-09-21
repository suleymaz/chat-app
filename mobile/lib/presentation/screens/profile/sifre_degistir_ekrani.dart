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
        _genelHata = hata is ApiException ? hata.message : 'Şifre değiştirilemedi';
        _alanHatalari = hata is ApiException ? hata.alanHatalari : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _genelHata = 'Beklenmeyen bir hata oluştu');
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  Future<void> _basariliUyarisi() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Şifren değiştirildi'),
        content: const Text(
          'Güvenlik için tüm cihazlardaki oturumlar sonlandırıldı. '
          'Yeni şifrenle tekrar giriş yapman gerekiyor.',
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
      appBar: AppBar(title: const Text('Şifre değiştir')),
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
                    label: 'Mevcut şifre',
                    icon: Icons.lock_outline,
                    sifreMi: true,
                    aktif: !_kaydediliyor,
                    hataMetni: _alanHatalari?['currentPassword'],
                    dogrula: (deger) {
                      if (deger == null || deger.isEmpty) return 'Mevcut şifre gerekli';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _yeniController,
                    label: 'Yeni şifre',
                    icon: Icons.lock_reset_outlined,
                    sifreMi: true,
                    aktif: !_kaydediliyor,
                    hataMetni: _alanHatalari?['newPassword'],
                    dogrula: _yeniSifreDogrula,
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _tekrarController,
                    label: 'Yeni şifre (tekrar)',
                    icon: Icons.lock_reset_outlined,
                    sifreMi: true,
                    aktif: !_kaydediliyor,
                    dogrula: (deger) {
                      if (deger != _yeniController.text) return 'Şifreler eşleşmiyor';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Şifre en az 8 karakter olmalı; bir büyük harf, bir küçük harf '
                    've bir rakam icermeli.',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    metin: 'Şifreyi değiştir',
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

    if (sifre.length < 8) return 'Şifre en az 8 karakter olmalı';
    if (!RegExp(r'[a-z]').hasMatch(sifre)) return 'En az bir küçük harf içermeli';
    if (!RegExp(r'[A-Z]').hasMatch(sifre)) return 'En az bir büyük harf içermeli';
    if (!RegExp(r'[0-9]').hasMatch(sifre)) return 'En az bir rakam icermeli';
    if (sifre == _mevcutController.text) return 'Yeni şifre eskisiyle aynı olamaz';

    return null;
  }
}
