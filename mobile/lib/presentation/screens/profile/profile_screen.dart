import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kullanici = ref.watch(authProvider).kullanici;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(kullanici?.fullName ?? ''),
            const SizedBox(height: 8),
            Text('@${kullanici?.username ?? ''}'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).cikisYap(),
              icon: const Icon(Icons.logout),
              label: const Text('Cikis yap'),
            ),
          ],
        ),
      ),
    );
  }
}