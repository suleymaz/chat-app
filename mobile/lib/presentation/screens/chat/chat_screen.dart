import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String conversationId;
  final String? userId;

  const ChatScreen({super.key, required this.conversationId, this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbet')),
      body: Center(
        child: Text('conversationId: $conversationId\nuserId: $userId'),
      ),
    );
  }
}