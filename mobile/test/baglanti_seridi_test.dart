import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/presentation/providers/socket_provider.dart';
import 'package:chat_app/presentation/widgets/baglanti_seridi.dart';

const uyari = 'Bağlantı yok, yeniden deneniyor…';

Future<void> seridiYukle(WidgetTester tester, Stream<bool> durum) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [socketBagliProvider.overrideWith((ref) => durum)],
      child: const MaterialApp(
        home: Scaffold(body: Column(children: [BaglantiSeridi()])),
      ),
    ),
  );
}

void main() {
  testWidgets('durum henuz bilinmiyorken serit gosterilmez', (tester) async {
    final kontrol = StreamController<bool>();

    await seridiYukle(tester, kontrol.stream);
    await tester.pump();

    // Uygulama her acilista uyariyla karsilamamali
    expect(find.text(uyari), findsNothing);

    await kontrol.close();
  });

  testWidgets('baglanti varken serit gosterilmez', (tester) async {
    final kontrol = StreamController<bool>();

    await seridiYukle(tester, kontrol.stream);
    kontrol.add(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text(uyari), findsNothing);

    await kontrol.close();
  });

  testWidgets('baglanti koptuktan sonra serit gecikmeli belirir', (tester) async {
    final kontrol = StreamController<bool>();

    await seridiYukle(tester, kontrol.stream);
    kontrol.add(true);
    await tester.pump();

    kontrol.add(false);
    await tester.pump();

    // Kisa kopmalarda ekran oynamasin diye serit hemen gosterilmiyor
    expect(find.text(uyari), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text(uyari), findsOneWidget);

    await kontrol.close();
  });

  testWidgets('baglanti geri gelince serit beklemeden kalkar', (tester) async {
    final kontrol = StreamController<bool>();

    await seridiYukle(tester, kontrol.stream);
    kontrol.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(uyari), findsOneWidget);

    kontrol.add(true);
    await tester.pump();
    expect(find.text(uyari), findsNothing);

    await kontrol.close();
  });

  testWidgets('kopma gecikme dolmadan duzelirse serit hic gorunmez', (tester) async {
    final kontrol = StreamController<bool>();

    await seridiYukle(tester, kontrol.stream);
    kontrol.add(false);
    await tester.pump();

    kontrol.add(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text(uyari), findsNothing);

    await kontrol.close();
  });
}
