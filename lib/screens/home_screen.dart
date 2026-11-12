import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<dynamic> _chats = [];
  Map<String, dynamic> _users = {};

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    final res = await ApiService.post('chat_list', {});
    if (res['status'] == 'ok') {
      setState(() {
        _chats = res['items'] ?? [];
        _users = res['users'] ?? {};
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // تابع برای تشخیص آواتار و نام
  String _getChatName(dynamic chat) {
    if (chat['t'] == 'p') {
      String uid = chat['uid'].toString();
      return _users[uid]?['n'] ?? 'کاربر';
    }
    return chat['name'] ?? 'گروه/کانال';
  }

  String _getAvatarText(dynamic chat) {
    return _getChatName(chat).toString().substring(0, 1).toUpperCase();
  }

  // تابع برای پیش‌نمایش آخرین پیام
  String _getLastMessage(dynamic chat) {
    if (chat['last'] == null) return 'بدون پیام';
    String type = chat['last']['type'] ?? 'text';
    String text = chat['last']['text'] ?? '';
    
    if (type == 'image') return '📷 عکس';
    if (type == 'voice') return '🎤 پیام صوتی';
    if (type == 'poll') return '📊 نظرسنجی';
    if (type == 'file') return '📎 فایل';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Parvaz', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 24)),
          backgroundColor: Colors.white,
          elevation: 1,
          actions: [
            IconButton(icon: const Icon(Icons.search, color: Colors.grey), onPressed: () {}),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchChats,
                child: ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final unread = chat['unread'] ?? 0;
                    final isOnline = false; // می‌توانید بعداً منطق آنلاین بودن را اضافه کنید
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blue,
                        child: Text(
                          _getAvatarText(chat),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getChatName(chat),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat['ver'] == true) 
                            const Icon(Icons.verified, color: Colors.blue, size: 16),
                        ],
                      ),
                      subtitle: Text(
                        _getLastMessage(chat),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: unread > 0 ? Colors.black87 : Colors.grey),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            chat['last'] != null 
                                ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(chat['last']['ts'] * 1000))
                                : '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unread.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        // اینجا بعداً صفحه چت را باز می‌کنیم
                      },
                    );
                  },
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.blue,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }
}
