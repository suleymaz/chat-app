import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/medya_secici.dart';
import '../../../data/models/user_model.dart';
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
  final _epostaController = TextEditingController();
  final _telefonController = TextEditingController();
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
    _epostaController.text = kullanici?.email ?? '';
    _telefonController.text = kullanici?.phone ?? '';
    _bioController.text = kullanici?.bio ?? '';
  }

  @override
  void dispose() {
    _adController.dispose();
    _kullaniciAdiController.dispose();
    _epostaController.dispose();
    _telefonController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Yalnizca degisen alanlar gonderilir - sunucu bos govdeyi reddediyor
  Map<String, dynamic> _degisenAlanlar() {
    final kullanici = ref.read(authProvider).kullanici;
    final veriler = <String, dynamic>{};

    final ad = _adController.text.trim();
    final kullaniciAdi = _kullaniciAdiController.text.trim();
    final eposta = _epostaController.text.trim();
    final telefon = _telefonController.text.trim();
    final bio = _bioController.text.trim();

    if (ad != (kullanici?.fullName ?? '')) veriler['fullName'] = ad;
    if (kullaniciAdi != (kullanici?.username ?? '')) veriler['username'] = kullaniciAdi;
    if (eposta != (kullanici?.email ?? '')) veriler['email'] = eposta;
    if (telefon != (kullanici?.phone ?? '')) veriler['phone'] = telefon;
    if (bio != (kullanici?.bio ?? '')) veriler['bio'] = bio.isEmpty ? null : bio;

    return veriler;
  }

  // Hesaba giris icin kullanilan alanlar; degismeleri sifre onayi gerektiriyor
  static const _kimlikAlanlari = ['username', 'email', 'phone'];

  /// Kimlik alanlarini degistirmeden once mevcut şifreyi sorar.
  /// Vazgeçilirse null döner.
  Future<String?> _sifreSor() async {
    final sifre = await showDialog<String>(
      context: context,
      builder: (context) => const _SifreOnayDiyalogu(),
    );

    return (sifre == null || sifre.isEmpty) ? null : sifre;
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    final veriler = _degisenAlanlar();

    if (veriler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değişiklik yok')),
      );
      return;
    }

    // Giris bilgileri degisiyorsa sunucu mevcut sifreyi istiyor
    if (_kimlikAlanlari.any(veriler.containsKey)) {
      final sifre = await _sifreSor();
      if (sifre == null) return;

      veriler['currentPassword'] = sifre;
    }

    if (!mounted) return;

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
        const SnackBar(content: Text('Profil güncellendi')),
      );
    } on DioException catch (e) {
      final hata = e.error;
      if (!mounted) return;
      setState(() {
        _genelHata = hata is ApiException ? hata.message : 'Profil güncellenemedi';
        _alanHatalari = hata is ApiException ? hata.alanHatalari : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _genelHata = 'Beklenmeyen bir hata oluştu');
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
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.pop(context);
                _avatarYukle(galeriden: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Fotoğraf çek'),
              onTap: () {
                Navigator.pop(context);
                _avatarYukle(galeriden: false);
              },
            ),
            if (avatarVar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text(
                  'Fotoğrafı kaldır',
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
        const SnackBar(content: Text('Profil fotoğrafı güncellendi')),
      );
    } catch (hata) {
      // Sunucunun sebebi gizlenmemeli; "yüklenemedi" demek hatayi bulunamaz
      // hale getiriyordu
      debugPrint('Avatar yuklenemedi: $hata');
      if (mounted) _uyari(_hataMetni(hata, 'Fotoğraf yüklenemedi'));
    } finally {
      if (mounted) setState(() => _avatarYukleniyor = false);
    }
  }

  Future<void> _avatarSil() async {
    setState(() => _avatarYukleniyor = true);

    try {
      final guncel = await ref.read(userRepositoryProvider).avatarSil();
      ref.read(authProvider.notifier).kullaniciGuncelle(guncel);
    } catch (hata) {
      debugPrint('Avatar silinemedi: $hata');
      if (mounted) _uyari(_hataMetni(hata, 'Fotoğraf kaldırılamadı'));
    } finally {
      if (mounted) setState(() => _avatarYukleniyor = false);
    }
  }

  // Sunucudan gelen aciklamayi kullanir, yoksa genel metne duser
  String _hataMetni(Object hata, String varsayilan) {
    final ic = hata is DioException ? hata.error : hata;
    return ic is ApiException ? ic.message : varsayilan;
  }

  void _uyari(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: AppColors.error),
    );
  }

  // Kullanici bilgisi degistiginde (giris tamamlandi, profil kaydedildi)
  // dokunulmamis alanlari tazeler. Kullanicinin yazdigi deger ezilmez.
  void _alanlariTazele(UserModel? onceki, UserModel? yeni) {
    void ayarla(TextEditingController kontrol, String? eskiDeger, String? yeniDeger) {
      if (kontrol.text == (eskiDeger ?? '')) kontrol.text = yeniDeger ?? '';
    }

    ayarla(_adController, onceki?.fullName, yeni?.fullName);
    ayarla(_kullaniciAdiController, onceki?.username, yeni?.username);
    ayarla(_epostaController, onceki?.email, yeni?.email);
    ayarla(_telefonController, onceki?.phone, yeni?.phone);
    ayarla(_bioController, onceki?.bio, yeni?.bio);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (onceki, yeni) {
      if (onceki?.kullanici != yeni.kullanici) {
        _alanlariTazele(onceki?.kullanici, yeni.kullanici);
      }
    });

    final kullanici = ref.watch(authProvider).kullanici;

    return Scaffold(
      // Ayarlara alt menuden gecildigi icin buradaki kisayol kaldirildi
      appBar: AppBar(title: const Text('Profil')),
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
                      if (metin.length < 2) return 'Ad soyad en az 2 karakter olmalı';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _kullaniciAdiController,
                    label: 'Kullanıcı adı',
                    icon: Icons.alternate_email,
                    aktif: !_kaydediliyor,
                    maksUzunluk: 30,
                    hataMetni: _alanHatalari?['username'],
                    dogrula: (deger) {
                      final metin = deger?.trim() ?? '';
                      if (metin.length < 3) {
                        return 'Kullanıcı adı en az 3 karakter olmalı';
                      }
                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(metin)) {
                        return 'Sadece küçük harf, rakam ve alt çizgi kullanılabilir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _epostaController,
                    label: 'E-posta',
                    icon: Icons.mail_outline,
                    aktif: !_kaydediliyor,
                    klavyeTipi: TextInputType.emailAddress,
                    hataMetni: _alanHatalari?['email'],
                    dogrula: (deger) {
                      final metin = deger?.trim() ?? '';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(metin)) {
                        return 'Geçerli bir e-posta adresi girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _telefonController,
                    label: 'Telefon',
                    hint: '05551234567',
                    icon: Icons.phone_outlined,
                    aktif: !_kaydediliyor,
                    klavyeTipi: TextInputType.phone,
                    maksUzunluk: 11,
                    hataMetni: _alanHatalari?['phone'],
                    dogrula: (deger) {
                      final metin = deger?.trim() ?? '';
                      if (!RegExp(r'^0[0-9]{10}$').hasMatch(metin)) {
                        return 'Telefon 05XXXXXXXXX biçiminde olmalı';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _bioController,
                    label: 'Hakkında',
                    hint: 'Kendinden kısaca bahset',
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
                    label: const Text('Şifre değiştir'),
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

/// Şifre onayı diyaloğu.
///
/// Ayrı bir widget: controller'ı kendi dispose'unda kapatıyor. Diyalog
/// kapandıktan hemen sonra çağıran taraftan dispose edilirse, kapanma
/// animasyonu sürerken TextField kapatılmış controller'ı kullanmaya çalışıyor
/// ve "used after being disposed" hatası veriyordu.
class _SifreOnayDiyalogu extends StatefulWidget {
  const _SifreOnayDiyalogu();

  @override
  State<_SifreOnayDiyalogu> createState() => _SifreOnayDiyaloguState();
}

class _SifreOnayDiyaloguState extends State<_SifreOnayDiyalogu> {
  final _kontrol = TextEditingController();
  bool _gizli = true;

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şifrenizi doğrulayın'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kullanıcı adı, e-posta ve telefon hesabınıza giriş için '
            'kullanılıyor. Değiştirmek için şifrenizi girin.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _kontrol,
            obscureText: _gizli,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Mevcut şifre',
              suffixIcon: IconButton(
                icon: Icon(
                  _gizli ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _gizli = !_gizli),
              ),
            ),
            onSubmitted: (deger) => Navigator.pop(context, deger),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _kontrol.text),
          child: const Text('Onayla'),
        ),
      ],
    );
  }
}
