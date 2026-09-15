import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/hata_kutusu.dart';
import 'package:dio/dio.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adSoyadController = TextEditingController();
  final _kullaniciAdiController = TextEditingController();
  final _epostaController = TextEditingController();
  final _telefonController = TextEditingController();
  final _sifreController = TextEditingController();

  bool _yukleniyor = false;
  String? _genelHata;
  Map<String, String> _alanHatalari = {};

  @override
  void dispose() {
    _adSoyadController.dispose();
    _kullaniciAdiController.dispose();
    _epostaController.dispose();
    _telefonController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _kayitOl() async {
    setState(() {
      _genelHata = null;
      _alanHatalari = {};
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _yukleniyor = true);

    try {
      await ref.read(authProvider.notifier).kayitOl(
            username: _kullaniciAdiController.text.trim().toLowerCase(),
            email: _epostaController.text.trim().toLowerCase(),
            phone: _telefonController.text.trim(),
            fullName: _adSoyadController.text.trim(),
            password: _sifreController.text,
          );
        } on ApiException catch (e) {
      setState(() {
        if (e.alanHatalari != null && e.alanHatalari!.isNotEmpty) {
          _alanHatalari = e.alanHatalari!;
        } else if (e.code == 'USERNAME_TAKEN') {
          _alanHatalari = {'username': e.message};
        } else if (e.code == 'EMAIL_TAKEN') {
          _alanHatalari = {'email': e.message};
        } else if (e.code == 'PHONE_TAKEN') {
          _alanHatalari = {'phone': e.message};
        } else {
          _genelHata = e.message;
        }
      });
    } on DioException catch (e) {
      final hata = e.error;
      if (hata is ApiException) {
        setState(() {
          if (hata.code == 'USERNAME_TAKEN') {
            _alanHatalari = {'username': hata.message};
          } else if (hata.code == 'EMAIL_TAKEN') {
            _alanHatalari = {'email': hata.message};
          } else if (hata.code == 'PHONE_TAKEN') {
            _alanHatalari = {'phone': hata.message};
          } else if (hata.alanHatalari != null && hata.alanHatalari!.isNotEmpty) {
            _alanHatalari = hata.alanHatalari!;
          } else {
            _genelHata = hata.message;
          }
        });
      } else {
        setState(() => _genelHata = 'Baglanti hatasi');
      }
    } catch (e) {
      setState(() => _genelHata = 'Beklenmeyen bir hata olustu');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _yukleniyor ? null : () => context.pop(),
        ),
        title: const Text('Hesap olustur'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Birkac bilgiyle baslayalim',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_genelHata != null) ...[
                      HataKutusu(mesaj: _genelHata!),
                      const SizedBox(height: 16),
                    ],

                    AppTextField(
                      controller: _adSoyadController,
                      label: 'Ad soyad',
                      hint: 'Ahmet Yilmaz',
                      icon: Icons.badge_outlined,
                      aktif: !_yukleniyor,
                      klavyeAksiyonu: TextInputAction.next,
                      hataMetni: _alanHatalari['fullName'],
                      dogrula: (deger) {
                        if (deger == null || deger.trim().length < 2) {
                          return 'Ad soyad en az 2 karakter olmali';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: _kullaniciAdiController,
                      label: 'Kullanici adi',
                      hint: 'ahmet',
                      icon: Icons.alternate_email,
                      aktif: !_yukleniyor,
                      klavyeAksiyonu: TextInputAction.next,
                      hataMetni: _alanHatalari['username'],
                      maksUzunluk: 30,
                      dogrula: (deger) {
                        final d = deger?.trim().toLowerCase() ?? '';
                        if (d.length < 3) return 'En az 3 karakter olmali';
                        if (!RegExp(r'^[a-z0-9_]+$').hasMatch(d)) {
                          return 'Sadece kucuk harf, rakam ve alt cizgi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: _epostaController,
                      label: 'E-posta',
                      hint: 'ahmet@ornek.com',
                      icon: Icons.mail_outline,
                      klavyeTipi: TextInputType.emailAddress,
                      aktif: !_yukleniyor,
                      klavyeAksiyonu: TextInputAction.next,
                      hataMetni: _alanHatalari['email'],
                      dogrula: (deger) {
                        final d = deger?.trim() ?? '';
                        if (d.isEmpty) return 'E-posta gerekli';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(d)) {
                          return 'Gecerli bir e-posta girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: _telefonController,
                      label: 'Telefon',
                      hint: '+905551234567',
                      icon: Icons.phone_outlined,
                      klavyeTipi: TextInputType.phone,
                      aktif: !_yukleniyor,
                      klavyeAksiyonu: TextInputAction.next,
                      hataMetni: _alanHatalari['phone'],
                      dogrula: (deger) {
                        final d = deger?.trim() ?? '';
                        if (!RegExp(r'^\+90[0-9]{10}$').hasMatch(d)) {
                          return '+905XXXXXXXXX formatinda olmali';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: _sifreController,
                      label: 'Sifre',
                      hint: 'En az 8 karakter',
                      icon: Icons.lock_outline,
                      sifreMi: true,
                      aktif: !_yukleniyor,
                      klavyeAksiyonu: TextInputAction.done,
                      gonderildiginde: (_) => _kayitOl(),
                      hataMetni: _alanHatalari['password'],
                      dogrula: (deger) {
                        final d = deger ?? '';
                        if (d.length < 8) return 'En az 8 karakter olmali';
                        if (!RegExp(r'[a-z]').hasMatch(d)) return 'En az bir kucuk harf gerekli';
                        if (!RegExp(r'[A-Z]').hasMatch(d)) return 'En az bir buyuk harf gerekli';
                        if (!RegExp(r'[0-9]').hasMatch(d)) return 'En az bir rakam gerekli';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Sifre en az 8 karakter olmali, buyuk harf, kucuk harf ve rakam icermeli.',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 24),

                    AppButton(
                      metin: 'Kayit ol',
                      yukleniyor: _yukleniyor,
                      onPressed: _kayitOl,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Zaten hesabin var mi?',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: _yukleniyor ? null : () => context.pop(),
                          child: const Text(
                            'Giris yap',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}










