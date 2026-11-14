import 'package:flutter/material.dart';
import 'common.dart';

class ChatScreen extends StatefulWidget {
  final String chat;
  final int cid;
  final int peer;
  final String title;
  final String avatar;
  final bool verified;
  final String role;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.cid,
    required this.peer,
    required this.title,
    this.avatar = '',
    this.verified = false,
    this.role = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: const Center(child: Text('صفحه چت هنوز آماده نیست...')),
    );
  }
}
