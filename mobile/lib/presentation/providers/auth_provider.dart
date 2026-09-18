import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../data/datasources/push_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/user_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

final pushServiceProvider = Provider<PushService>((ref) {
  final servis = PushService(ref.watch(notificationRepositoryProvider));
  ref.onDispose(servis.temizle);
  return servis;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(apiClientProvider)),
);

// Oturum durumu
enum OturumDurumu { baslangic, girisYapildi, girisYapilmadi }

class AuthState {
  final OturumDurumu durum;
  final UserModel? kullanici;

  AuthState({this.durum = OturumDurumu.baslangic, this.kullanici});

  AuthState copyWith({OturumDurumu? durum, UserModel? kullanici}) {
    return AuthState(
      durum: durum ?? this.durum,
      kullanici: kullanici ?? this.kullanici,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final UserRepository _userRepo;

  AuthNotifier(this._authRepo, this._userRepo) : super(AuthState());

  // Cikis oncesi calistirilacak is - FCM token'i token'lar silinmeden once
  // sunucudan kaldirmak icin main.dart tarafindan ayarlanir
  Future<void> Function()? cikisOncesi;

  // Uygulama acilisinda kayitli token varsa oturumu geri yukler
  Future<void> baslat() async {
    final token = await SecureStorage.accessTokenAl();

    if (token == null) {
      state = AuthState(durum: OturumDurumu.girisYapilmadi);
      return;
    }

    try {
      final kullanici = await _userRepo.profilimiGetir();
      state = AuthState(durum: OturumDurumu.girisYapildi, kullanici: kullanici);
    } catch (_) {
      await SecureStorage.temizle();
      state = AuthState(durum: OturumDurumu.girisYapilmadi);
    }
  }

  Future<void> girisYap(String identifier, String password) async {
    final kullanici = await _authRepo.girisYap(
      identifier: identifier,
      password: password,
    );

    state = AuthState(durum: OturumDurumu.girisYapildi, kullanici: kullanici);
  }

  Future<void> kayitOl({
    required String username,
    required String email,
    required String phone,
    required String fullName,
    required String password,
  }) async {
    final kullanici = await _authRepo.kayitOl(
      username: username,
      email: email,
      phone: phone,
      fullName: fullName,
      password: password,
    );

    state = AuthState(durum: OturumDurumu.girisYapildi, kullanici: kullanici);
  }

  Future<void> cikisYap() async {
    await cikisOncesi?.call();
    await _authRepo.cikisYap();
    state = AuthState(durum: OturumDurumu.girisYapilmadi);
  }

  // Profil guncellendiginde state'i tazeler
  void kullaniciGuncelle(UserModel kullanici) {
    state = state.copyWith(kullanici: kullanici);
  }

  // Interceptor oturumu kapattiginda cagrilir
  void oturumSonlandir() {
    state = AuthState(durum: OturumDurumu.girisYapilmadi);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(userRepositoryProvider),
  );
});