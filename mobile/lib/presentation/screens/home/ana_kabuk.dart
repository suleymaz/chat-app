import 'package:flutter/material.dart';

import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';

/// Uygulamanin ana kabugu: sohbetler, profil ve ayarlar sekmeleri.
///
/// Sekmeler IndexedStack icinde tutuluyor, boylece sekme degistirince ekranlar
/// bastan kurulmuyor; sohbet listesinin kaydirma konumu ve profil formundaki
/// yazilanlar korunuyor.
class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key});

  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk> {
  int _sekme = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _sekme,
        children: const [
          HomeScreen(),
          ProfileScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sekme,
        onDestinationSelected: (indeks) => setState(() => _sekme = indeks),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Sohbetler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
