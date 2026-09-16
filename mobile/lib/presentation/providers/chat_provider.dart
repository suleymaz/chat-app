import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/conversation_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'auth_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

class SohbetListesiNotifier extends StateNotifier<AsyncValue<List<ConversationModel>>> {
  final ChatRepository _repo;
  final bool arsivlenmis;

  SohbetListesiNotifier(this._repo, {this.arsivlenmis = false})
      : super(const AsyncValue.loading()) {
    yukle();
  }

  Future<void> yukle() async {
    state = const AsyncValue.loading();

    try {
      final sohbetler = await _repo.sohbetleriGetir(arsivlenmis: arsivlenmis);
      state = AsyncValue.data(sohbetler);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // Pull-to-refresh - loading gostermeden sessizce tazeler
  Future<void> tazele() async {
    try {
      final sohbetler = await _repo.sohbetleriGetir(arsivlenmis: arsivlenmis);
      state = AsyncValue.data(sohbetler);
    } catch (_) {
      // Tazeleme basarisiz olursa mevcut liste korunur
    }
  }

  // Bir sohbetin okunmamis sayacini sifirlar
  void okunduIsaretle(String conversationId) {
    final mevcut = state.value;
    if (mevcut == null) return;

    state = AsyncValue.data([
      for (final s in mevcut)
        if (s.id == conversationId) s.copyWith(unreadCount: 0) else s,
    ]);
  }

  // Sohbeti listeden cikarir (silme/arsivleme sonrasi)
  void listedenCikar(String conversationId) {
    final mevcut = state.value;
    if (mevcut == null) return;

    state = AsyncValue.data(mevcut.where((s) => s.id != conversationId).toList());
  }
}

final sohbetListesiProvider =
    StateNotifierProvider<SohbetListesiNotifier, AsyncValue<List<ConversationModel>>>(
  (ref) => SohbetListesiNotifier(ref.watch(chatRepositoryProvider)),
);

final arsivListesiProvider =
    StateNotifierProvider<SohbetListesiNotifier, AsyncValue<List<ConversationModel>>>(
  (ref) => SohbetListesiNotifier(ref.watch(chatRepositoryProvider), arsivlenmis: true),
);