import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/hata_kutusu.dart';
import 'package:dio/dio.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _sifreController = TextEditingController();

  bool _yukleniyor = false;
  String? _genelHata;

  @override
  void dispose() {
    _identifierController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _yukleniyor = true;
      _genelHata = null;
    });

    try {
      await ref.read(authProvider.notifier).girisYap(
            _identifierController.text.trim(),
            _sifreController.text,
          );
      // Yonlendirmeyi router hallediyor
        } on DioException catch (e) {
      final hata = e.error;
      setState(() {
        _genelHata = hata is ApiException ? hata.message : 'Bağlantı hatası';
      });
    } catch (_) {
      setState(() => _genelHata = 'Beklenmeyen bir hata oluştu');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _logo(),
                    const SizedBox(height: 40),
                    const Text(
                      'Hoş geldiniz',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Devam etmek için giriş yap',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 28),

                    if (_genelHata != null) ...[
                      HataKutusu(mesaj: _genelHata!),
                      const SizedBox(height: 16),
                    ],

                    AppTextField(
                      controller: _identifierController,
                      label: 'Kullanıcı adı, e-posta veya telefon',
                      hint: 'örnek: ahmet',
                      icon: Icons.person_outline,
                      aktif: !_yukleniyor,
                      klavyeAksiyonu: TextInputAction.next,
                      dogrula: (deger) {
                        if (deger == null || deger.trim().isEmpty) {
                          return 'Bu alan boş bırakılamaz';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: _sifreController,
                      label: 'Şifre',
                      hint: 'Şifreni gir',
                      icon: Icons.lock_outline,
                      sifreMi: true,
                      aktif: !_yukleniyor,
                      klavyeAksiyonu: TextInputAction.done,
                      gonderildiginde: (_) => _girisYap(),
                      dogrula: (deger) {
                        if (deger == null || deger.isEmpty) {
                          return 'Şifre gerekli';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    AppButton(
                      metin: 'Giriş yap',
                      yukleniyor: _yukleniyor,
                      onPressed: _girisYap,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Hesabın yok mu?',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: _yukleniyor
                              ? null
                              : () => context.push(Rotalar.register),
                          child: const Text(
                            'Kayıt ol',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.forum_outlined, size: 38, color: Colors.white),
      ),
    );
  }
}