import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';

      final response = await http.post(
        Uri.parse('https://noorir.isfpardaz.ir/api.php'),
        body: {
          'action': 'chat_list',
          'username': username,
        },
      );
      final data = jsonDecode(response.body);
      
      if (data['status'] == 'ok') {
        setState(() {
          chats = data['items'];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parvaz', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3390ec))),
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chat: chat))),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text((chat['name'] ?? 'U')[0]),
                  ),
                  title: Text(chat['name'] ?? 'چت', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(chat['last'] != null ? chat['last']['text'] : 'بدون پیام', maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
    );
  }
}
