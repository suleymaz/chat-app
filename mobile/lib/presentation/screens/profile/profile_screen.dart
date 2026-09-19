import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/medya_secici.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/hata_kutusu.dart';
import '../../widgets/kullanici_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adController = TextEditingController();
  final _kullaniciAdiController = TextEditingController();
  final _bioController = TextEditingController();

  bool _kaydediliyor = false;
  bool _avatarYukleniyor = false;
  String? _genelHata;
  Map<String, String>? _alanHatalari;

  @override
  void initState() {
    super.initState();

    final kullanici = ref.read(authProvider).kullanici;
    _adController.text = kullanici?.fullName ?? '';
    _kullaniciAdiController.text = kullanici?.username ?? '';
    _bioController.text = kullanici?.bio ?? '';
  }

  @override
  void dispose() {
    _adController.dispose();
    _kullaniciAdiController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Yalnizca degisen alanlar gonderilir - sunucu bos govdeyi reddediyor
  Map<String, dynamic> _degisenAlanlar() {
    final kullanici = ref.read(authProvider).kullanici;
    final veriler = <String, dynamic>{};

    final ad = _adController.text.trim();
    final kullaniciAdi = _kullaniciAdiController.text.trim();
    final bio = _bioController.text.trim();

    if (ad != (kullanici?.fullName ?? '')) veriler['fullName'] = ad;
    if (kullaniciAdi != (kullanici?.username ?? '')) veriler['username'] = kullaniciAdi;
    if (bio != (kullanici?.bio ?? '')) veriler['bio'] = bio.isEmpty ? null : bio;

    return veriler;
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    final veriler = _degisenAlanlar();

    if (veriler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Degisiklik yok')),
      );
      return;
    }

    setState(() {
      _kaydediliyor = true;
      _genelHata = null;
      _alanHatalari = null;
    });

    try {
      final guncel = await ref.read(userRepositoryProvider).profilGuncelle(veriler);
      ref.read(authProvider.notifier).kullaniciGuncelle(guncel);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil guncellendi')),
      );
    } on DioException catch (e) {
      final hata = e.error;
      if (!mounted) return;
      setState(() {
        _genelHata = hata is ApiException ? hata.message : 'Profil guncellenemedi';
        _alanHatalari = hata is ApiException ? hata.alanHatalari : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _genelHata = 'Beklenmeyen bir hata olustu');
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  void _avatarMenusu() {
    final avatarVar = ref.read(authProvider).kullanici?.avatarUrl != null;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Galeriden sec'),
              onTap: () {
                Navigator.pop(context);
                _avatarYukle(galeriden: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Fotograf cek'),
              onTap: () {
                Navigator.pop(context);
                _avatarYukle(galeriden: false);
              },
            ),
            if (avatarVar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text(
                  'Fotografi kaldir',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _avatarSil();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _avatarYukle({required bool galeriden}) async {
    final yol =
        galeriden ? await MedyaSecici.galeriden() : await MedyaSecici.kameradan();

    if (yol == null || !mounted) return;

    setState(() => _avatarYukleniyor = true);

    try {
      final guncel = await ref.read(userRepositoryProvider).avatarYukle(yol);
      ref.read(authProvider.notifier).kullaniciGuncelle(guncel);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotografi guncellendi')),
      );
    } catch (_) {
      if (mounted) _uyari('Fotograf yuklenemedi');
    } finally {
      if (mounted) setState(() => _avatarYukleniyor = false);
    }
  }

  Future<void> _avatarSil() async {
    setState(() => _avatarYukleniyor = true);

    try {
      final guncel = await ref.read(userRepositoryProvider).avatarSil();
      ref.read(authProvider.notifier).kullaniciGuncelle(guncel);
    } catch (_) {
      if (mounted) _uyari('Fotograf kaldirilamadi');
    } finally {
      if (mounted) setState(() => _avatarYukleniyor = false);
    }
  }

  void _uyari(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kullanici = ref.watch(authProvider).kullanici;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onPressed: () => context.push(Rotalar.settings),
          ),
        ],
      ),
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
                  _avatarBolumu(kullanici?.avatarUrl, kullanici?.basHarfler ?? '?'),
                  const SizedBox(height: 8),
                  Text(
                    '@${kullanici?.username ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 28),

                  if (_genelHata != null) ...[
                    HataKutusu(mesaj: _genelHata!),
                    const SizedBox(height: 16),
                  ],

                  AppTextField(
                    controller: _adController,
                    label: 'Ad soyad',
                    icon: Icons.badge_outlined,
                    aktif: !_kaydediliyor,
                    maksUzunluk: 100,
                    hataMetni: _alanHatalari?['fullName'],
                    dogrula: (deger) {
                      final metin = deger?.trim() ?? '';
                      if (metin.length < 2) return 'Ad soyad en az 2 karakter olmali';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _kullaniciAdiController,
                    label: 'Kullanici adi',
                    icon: Icons.alternate_email,
                    aktif: !_kaydediliyor,
                    maksUzunluk: 30,
                    hataMetni: _alanHatalari?['username'],
                    dogrula: (deger) {
                      final metin = deger?.trim() ?? '';
                      if (metin.length < 3) {
                        return 'Kullanici adi en az 3 karakter olmali';
                      }
                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(metin)) {
                        return 'Sadece kucuk harf, rakam ve alt cizgi kullanilabilir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _bioController,
                    label: 'Hakkinda',
                    hint: 'Kendinden kisaca bahset',
                    icon: Icons.notes_outlined,
                    aktif: !_kaydediliyor,
                    maksUzunluk: 160,
                    hataMetni: _alanHatalari?['bio'],
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    metin: 'Kaydet',
                    icon: Icons.check,
                    yukleniyor: _kaydediliyor,
                    onPressed: _kaydet,
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () => context.push(Rotalar.changePassword),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Sifre degistir'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarBolumu(String? avatarUrl, String basHarfler) {
    return Center(
      child: Stack(
        children: [
          KullaniciAvatar(avatarUrl: avatarUrl, basHarfler: basHarfler, boyut: 104),
          if (_avatarYukleniyor)
            const Positioned.fill(
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _avatarYukleniyor ? null : _avatarMenusu,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: const Icon(Icons.photo_camera, size: 17, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
