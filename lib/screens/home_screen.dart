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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'خطا در دریافت چت‌ها')));
      }
    }
  }

  String _getChatName(dynamic chat) {
    if (chat['t'] == 'p') {
      String uid = chat['uid'].toString();
      return _users[uid]?['n'] ?? 'کاربر';
    }
    return chat['name'] ?? 'گروه/کانال';
  }

  String _getAvatarText(dynamic chat) {
    final name = _getChatName(chat);
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }

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

  String _getTime(dynamic chat) {
    if (chat['last'] == null) return '';
    int ts = chat['last']['ts'];
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Parvaz'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchChats,
                child: ListView.separated(
                  itemCount: _chats.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final unread = chat['unread'] ?? 0;
                    final isVerified = chat['ver'] == true;
                    
                    // پیدا کردن عکس آواتار (برای گروه‌ها یا پیوی)
                    String? avatarUrl;
                    if (chat['t'] == 'p' && chat['uid'].toString() != '0') {
                      final p = _users[chat['uid'].toString()]?['p'];
                      if (p != null && p != '') avatarUrl = 'https://noorir.isfpardaz.ir/uploads/$p';
                    } else if (chat['av'] != null && chat['av'] != '') {
                      avatarUrl = 'https://noorir.isfpardaz.ir/${chat['av']}';
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blue,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(
                          _getAvatarText(chat),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ) : null,
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
                          if (isVerified) 
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.verified, color: Colors.blue, size: 16),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        _getLastMessage(chat),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: unread > 0 ? Colors.black87 : Colors.grey[600]),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _getTime(chat),
                            style: TextStyle(fontSize: 12, color: unread > 0 ? Colors.blue : Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unread.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            const SizedBox(height: 18),
                        ],
                      ),
                      onTap: () {
                        // اینجا بعداً برای باز کردن صفحه چت کد می‌نویسیم
                      },
                    );
                  },
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFF3390ec),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }
}
