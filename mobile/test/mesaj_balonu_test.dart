import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/data/models/message_model.dart';
import 'package:chat_app/presentation/widgets/mesaj_balonu.dart';

MessageModel metinMesaji({
  String? content = 'merhaba',
  DateTime? deliveredAt,
  DateTime? readAt,
  DateTime? deletedAt,
  MesajDurumu? yerelDurum,
}) {
  return MessageModel(
    id: 'm1',
    conversationId: 's1',
    senderId: 'k1',
    content: content,
    deliveredAt: deliveredAt,
    readAt: readAt,
    deletedAt: deletedAt,
    createdAt: DateTime(2026, 1, 1, 9, 5),
    yerelDurum: yerelDurum,
  );
}

Future<void> balonYukle(
  WidgetTester tester,
  MessageModel mesaj, {
  bool benimMi = true,
  VoidCallback? onTekrarDene,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MesajBalonu(mesaj: mesaj, benimMi: benimMi, onTekrarDene: onTekrarDene),
      ),
    ),
  );
}

Color? ikonRengi(WidgetTester tester, IconData ikon) =>
    tester.widget<Icon>(find.byIcon(ikon)).color;

void main() {
  testWidgets('metin mesajinin icerigi ve saati gosterilir', (tester) async {
    await balonYukle(tester, metinMesaji());

    expect(find.text('merhaba'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
  });

  testWidgets('silinen mesajda icerik yerine uyari gosterilir', (tester) async {
    await balonYukle(tester, metinMesaji(content: 'gizli', deletedAt: DateTime.now()));

    expect(find.text('Bu mesaj silindi'), findsOneWidget);
    expect(find.text('gizli'), findsNothing);
  });

  group('gonderim durumu ikonu', () {
    testWidgets('gonderildi durumunda tek tik gosterilir', (tester) async {
      await balonYukle(tester, metinMesaji());

      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('iletildi durumunda cift tik soluk renkte gosterilir', (tester) async {
      await balonYukle(tester, metinMesaji(deliveredAt: DateTime.now()));

      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(ikonRengi(tester, Icons.done_all), AppColors.textTertiary);
    });

    testWidgets('okundu durumunda cift tik vurgulu renkte gosterilir', (tester) async {
      await balonYukle(
        tester,
        metinMesaji(deliveredAt: DateTime.now(), readAt: DateTime.now()),
      );

      expect(ikonRengi(tester, Icons.done_all), AppColors.primary);
    });

    // Durum bilgisi yalnizca gonderen icin anlamli; gelen mesajda tik olmamali
    testWidgets('gelen mesajda durum ikonu gosterilmez', (tester) async {
      await balonYukle(tester, metinMesaji(readAt: DateTime.now()), benimMi: false);

      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });
  });

  testWidgets('basarisiz mesajda tekrar deneme dugmesi calisir', (tester) async {
    var denendi = false;

    await balonYukle(
      tester,
      metinMesaji(yerelDurum: MesajDurumu.basarisiz),
      onTekrarDene: () => denendi = true,
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    expect(denendi, isTrue);
  });

  testWidgets('gonderilmeyi bekleyen mesajda ilerleme gostergesi cikar', (tester) async {
    await balonYukle(tester, metinMesaji(yerelDurum: MesajDurumu.gonderiliyor));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('gelen ve giden mesaj farkli hizalanir', (tester) async {
    await balonYukle(tester, metinMesaji(), benimMi: true);
    final giden = tester.widget<Row>(find.byType(Row).first).mainAxisAlignment;

    await balonYukle(tester, metinMesaji(), benimMi: false);
    final gelen = tester.widget<Row>(find.byType(Row).first).mainAxisAlignment;

    expect(giden, MainAxisAlignment.end);
    expect(gelen, MainAxisAlignment.start);
  });
}
