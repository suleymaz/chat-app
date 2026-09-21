import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/bos_durum.dart';
import '../../widgets/kullanici_avatar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<UserModel> _sonuclar = [];
  bool _yukleniyor = false;
  bool _aramaYapildi = false;
  String? _hata;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Her tusa basista istek atmamak icin 400ms bekletiyoruz
  void _terimDegisti(String terim) {
    _debounce?.cancel();

    if (terim.trim().length < 2) {
      setState(() {
        _sonuclar = [];
        _aramaYapildi = false;
        _hata = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _ara(terim.trim()));
  }

  Future<void> _ara(String terim) async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final sonuclar = await ref.read(userRepositoryProvider).kullaniciAra(terim);

      if (!mounted) return;
      setState(() {
        _sonuclar = sonuclar;
        _aramaYapildi = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final hata = e.error;
      setState(() {
        _hata = hata is ApiException ? hata.message : 'Arama yapılamadı';
        _aramaYapildi = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hata = 'Arama yapılamadı';
        _aramaYapildi = true;
      });
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // Kullaniciyla mevcut sohbet varsa oraya gider, yoksa yeni sohbet ekrani acilir
  Future<void> _sohbeteGit(UserModel kullanici) async {
    try {
      final sonuc = await ref.read(chatRepositoryProvider).kullaniciylaSohbet(kullanici.id);
      if (!mounted) return;

      final conversationId = sonuc['id'] as String?;

      if (conversationId != null) {
        context.pushReplacement('${Rotalar.chat}/$conversationId');
      } else {
        // Henuz sohbet yok - ilk mesajla olusturulacak
        context.pushReplacement('${Rotalar.chat}/yeni?userId=${kullanici.id}');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet açılamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _terimDegisti,
          decoration: const InputDecoration(
            hintText: 'Kullanıcı adı, e-posta veya telefon',
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _terimDegisti('');
              },
            ),
        ],
      ),
      body: _govde(),
    );
  }

  Widget _govde() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hata != null) {
      return BosDurum(
        icon: Icons.error_outline,
        baslik: 'Arama yapılamadı',
        aciklama: _hata,
      );
    }

    if (!_aramaYapildi) {
      return const BosDurum(
        icon: Icons.person_search_outlined,
        baslik: 'Kullanıcı ara',
        aciklama: 'En az 2 karakter yazarak aramaya baslayabilirsin',
      );
    }

    if (_sonuclar.isEmpty) {
      return const BosDurum(
        icon: Icons.search_off,
        baslik: 'Sonuç bulunamadı',
        aciklama: 'Farkli bir arama terimi deneyebilirsin',
      );
    }

    return ListView.separated(
      itemCount: _sonuclar.length,
      separatorBuilder: (context, index) => const Divider(indent: 76, height: 1),
      itemBuilder: (context, index) {
        final kullanici = _sonuclar[index];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: KullaniciAvatar(
            avatarUrl: kullanici.avatarUrl,
            basHarfler: kullanici.basHarfler,
            boyut: 46,
            cevrimici: kullanici.isOnline,
          ),
          title: Text(
            kullanici.fullName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            kullanici.bio?.isNotEmpty == true ? kullanici.bio! : '@${kullanici.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          onTap: () => _sohbeteGit(kullanici),
        );
      },
    );
  }
}