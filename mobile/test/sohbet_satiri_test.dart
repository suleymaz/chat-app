import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:chat_app/data/models/conversation_model.dart';
import 'package:chat_app/data/models/message_model.dart';
import 'package:chat_app/data/models/user_model.dart';
import 'package:chat_app/presentation/widgets/sohbet_satiri.dart';

const benimId = 'ben';

ConversationModel sohbet({
  int unreadCount = 0,
  bool isMuted = false,
  MessageModel? sonMesaj,
  bool cevrimici = false,
}) {
  return ConversationModel(
    id: 's1',
    user: UserModel(
      id: 'k2',
      username: 'ayse',
      fullName: 'Ayse Yilmaz',
      isOnline: cevrimici,
    ),
    lastMessage: sonMesaj,
    unreadCount: unreadCount,
    isMuted: isMuted,
    lastMessageAt: DateTime.now(),
  );
}

MessageModel mesaj({
  String? content = 'merhaba',
  String senderId = 'k2',
  MesajTipi tip = MesajTipi.text,
  DateTime? deletedAt,
  DateTime? readAt,
}) {
  return MessageModel(
    id: 'm1',
    conversationId: 's1',
    senderId: senderId,
    content: content,
    type: tip,
    deletedAt: deletedAt,
    readAt: readAt,
    createdAt: DateTime.now(),
  );
}

Future<void> satirYukle(WidgetTester tester, ConversationModel kayit) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SohbetSatiri(sohbet: kayit, benimId: benimId, onTap: () {}),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr');
  });

  testWidgets('kisi adi ve son mesaj gosterilir', (tester) async {
    await satirYukle(tester, sohbet(sonMesaj: mesaj()));

    expect(find.text('Ayse Yilmaz'), findsOneWidget);
    expect(find.text('merhaba'), findsOneWidget);
  });

  group('okunmamis rozeti', () {
    testWidgets('okunmamis mesaj yoksa rozet cikmaz', (tester) async {
      await satirYukle(tester, sohbet(sonMesaj: mesaj()));

      expect(find.text('0'), findsNothing);
    });

    testWidgets('okunmamis sayisi rozette gosterilir', (tester) async {
      await satirYukle(tester, sohbet(unreadCount: 3, sonMesaj: mesaj()));

      expect(find.text('3'), findsOneWidget);
    });

    // Rozet genisligi sabit; ucus basamakli sayilar tasmasin diye kisaltiliyor
    testWidgets('99 ustu sayilar kisaltilir', (tester) async {
      await satirYukle(tester, sohbet(unreadCount: 150, sonMesaj: mesaj()));

      expect(find.text('99+'), findsOneWidget);
      expect(find.text('150'), findsNothing);
    });
  });

  testWidgets('sessize alinan sohbette bildirim ikonu gosterilir', (tester) async {
    await satirYukle(tester, sohbet(isMuted: true, sonMesaj: mesaj()));

    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
  });

  testWidgets('sessize alinmamis sohbette ikon cikmaz', (tester) async {
    await satirYukle(tester, sohbet(sonMesaj: mesaj()));

    expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);
  });

  group('son mesaj ozeti', () {
    testWidgets('gorsel mesajda fotograf ikonu ve metni gosterilir', (tester) async {
      await satirYukle(tester, sohbet(sonMesaj: mesaj(tip: MesajTipi.image)));

      expect(find.text('Fotograf'), findsOneWidget);
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
    });

    testWidgets('silinen mesajda uyari metni gosterilir', (tester) async {
      await satirYukle(
        tester,
        sohbet(sonMesaj: mesaj(content: 'gizli', deletedAt: DateTime.now())),
      );

      expect(find.text('Bu mesaj silindi'), findsOneWidget);
      expect(find.text('gizli'), findsNothing);
    });
  });

  group('gonderim durumu', () {
    // Tik yalnizca son mesaji kendimiz gonderdiysek anlamli
    testWidgets('karsi tarafin mesajinda tik gosterilmez', (tester) async {
      await satirYukle(tester, sohbet(sonMesaj: mesaj(senderId: 'k2')));

      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('kendi gonderdigimiz okunmus mesajda cift tik cikar', (tester) async {
      await satirYukle(
        tester,
        sohbet(sonMesaj: mesaj(senderId: benimId, readAt: DateTime.now())),
      );

      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });
  });
}
