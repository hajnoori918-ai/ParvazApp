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
  String _err = '';

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id') ?? '';

      final response = await http.post(
        Uri.parse('https://noorir.isfpardaz.ir/api.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Dart/2.17 (dart:io)',
          'X-Session-ID': sessionId,
        },
        body: {
          'action': 'chat_list',
          'app_mode': '1',
        },
      );
      final data = jsonDecode(response.body);
      
      if (data['status'] == 'ok') {
        setState(() {
          chats = data['items'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _err = data['message'] ?? 'خطا در دریافت اطلاعات';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _err = 'خطای شبکه: $e';
        _loading = false;
      });
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
          : _err.isNotEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_err, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
              : chats.isEmpty
                  ? const Center(child: Text('هیچ چتی وجود ندارد', style: TextStyle(color: Colors.grey)))
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
