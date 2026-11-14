import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'api_service.dart';
import 'chat_screen.dart';
import 'common.dart';
import 'login_screen.dart';

Map<String, dynamic> _m(dynamic e) => Map<String, dynamic>.from(e as Map);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// 0=پروفایل 1=تنظیمات 2=مخاطبین 3=گفتگوها (ترتیب نوار پایین، مثل سایت)
  int tab = 3;
  String filter = 'all';
  String q = '';
  bool searching = false;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> groups = [];
  bool canStory = false;
  bool _busy = false, _paused = false, _loaded = false;
  DateTime _lastStories = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  final _searchC = TextEditingController();

  // مخاطبین
  final _cq = TextEditingController();
  List<Map<String, dynamic>> contacts = [];
  bool contactsBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _searchC.dispose();
    _cq.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _tick(force: true);
  }

  Future<void> _tick({bool force = false}) async {
    if (_busy || _paused || !mounted) return;
    _busy = true;
    final j = await Api.i.call('chat_list');
    if (j['status'] == 'ok' && mounted) {
      mergeUsers(j['users']);
      setState(() {
        items = (j['items'] as List).map(_m).toList();
        _loaded = true;
      });
    }
    if (mounted && (force || DateTime.now().difference(_lastStories).inSeconds > 40)) await _loadStories();
    _busy = false;
  }

  Future<void> _loadStories() async {
    _lastStories = DateTime.now();
    final j = await Api.i.call('stories_list');
    if (j['status'] == 'ok' && mounted) {
      mergeUsers(j['users']);
      setState(() {
        groups = (j['groups'] as List).map(_m).toList();
        canStory = j['can'] == true;
      });
    }
  }

  /* ---------- داده‌ی لیست ---------- */

  String chatName(Map<String, dynamic> it) {
    if (it['t'] == 'p') {
      final uid = (it['uid'] as num).toInt();
      return uid == meId ? 'پیام‌های ذخیره‌شده' : userName(uid);
    }
    return (it['name'] ?? '').toString();
  }

  List<Map<String, dynamic>> get sorted {
    final qq = q.trim().toLowerCase();
    final l = items.where((it) {
      final arch = (it['arch'] ?? 0) == 1;
      if (filter == 'arch') {
        if (!arch) return false;
      } else if (arch && qq.isEmpty) {
        return false;
      }
      if (filter == 'unread' && (it['unread'] ?? 0) == 0) return false;
      if ((filter == 'c' || filter == 'g' || filter == 'p') && it['t'] != filter) return false;
      return qq.isEmpty || chatName(it).toLowerCase().contains(qq);
    }).toList();
    l.sort((x, y) {
      final p = ((y['pin'] ?? 0) as num).compareTo((x['pin'] ?? 0) as num);
      if (p != 0) return p;
      final ty = (y['last'] is Map ? (y['last']['ts'] ?? 0) : 0) as num;
      final tx = (x['last'] is Map ? (x['last']['ts'] ?? 0) : 0) as num;
      return ty.compareTo(tx);
    });
    return l;
  }

  int _count(String k) {
    final live = items.where((i) => (i['arch'] ?? 0) != 1);
    if (k == 'all') return live.length;
    if (k == 'unread') return live.where((i) => (i['unread'] ?? 0) > 0).length;
    return live.where((i) => i['t'] == k).length;
  }

  int get totalUnread => items.fold<int>(0, (a, i) => a + (((i['mute'] ?? 0) == 1 || (i['arch'] ?? 0) == 1) ? 0 : ((i['unread'] ?? 0) as num).toInt()));

  (String, String) _lastText(Map<String, dynamic> it) {
    final l = it['last'];
    if (l is! Map) return ('', it['t'] == 'p' && it['uid'] == meId ? 'پیام‌هایت را اینجا ذخیره کن' : 'بدون پیام');
    final type = l['type']?.toString();
    final uid = (l['uid'] as num?)?.toInt() ?? 0;
    if (type == 'service') {
      const m = {'pin': 'پیامی را سنجاق کرد', 'call_start': 'ویس‌کال را شروع کرد', 'call_end': 'ویس‌کال را پایان داد'};
      final nm = users[uid]?['n']?.toString() ?? 'مدیر';
      return ('', '$nm ${m[l['text']] ?? l['text']}');
    }
    final t = previewText(type, l['text']?.toString());
    final mine = uid == meId;
    if (it['t'] == 'g') return (mine ? 'شما' : userName(uid), t);
    if (it['t'] == 'p' && mine) return ('شما', t);
    return ('', t);
  }

  /* ---------- باز کردن گفتگو ---------- */

  Future<void> openItem(Map<String, dynamic> it) async {
    final t = it['t'].toString();
    final cid = (it['cid'] as num?)?.toInt() ?? 0;
    final peer = t == 'p' ? (it['uid'] as num).toInt() : 0;
    await _openChat(ChatScreen(chat: t, cid: cid, peer: peer, title: chatName(it), avatar: (it['av'] ?? '').toString(), verified: it['ver'] == true, role: (it['role'] ?? '').toString()));
  }

  Future<void> _openChat(Widget w) async {
    _paused = true;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    _paused = false;
    if (mounted) _tick(force: true);
  }

  Future<void> openUserChat(int id) => _openChat(ChatScreen(chat: 'p', cid: 0, peer: id, title: id == meId ? 'پیام‌های ذخیره‌شده' : userName(id)));

  /* ---------- منوی نگه‌داشتن روی گفتگو ---------- */

  Future<void> chatMenu(Map<String, dynamic> it) async {
    final t = it['t'].toString();
    final key = t + (t == 'p' ? it['uid'].toString() : it['cid'].toString());
    Future<void> pref(Map<String, dynamic> o) async {
      final j = await Api.i.call('chat_pref', {'ckey': key, ...o});
      if (j['status'] != 'ok' && mounted) toast(context, (j['message'] ?? 'خطا').toString());
      _tick(force: true);
    }

    final acts = <(IconData, String, VoidCallback, bool)>[
      (Icons.push_pin_outlined, (it['pin'] ?? 0) == 1 ? 'برداشتن سنجاق' : 'سنجاق کردن', () => pref({'pinned': (it['pin'] ?? 0) == 1 ? 0 : 1}), false),
      (Icons.archive_outlined, (it['arch'] ?? 0) == 1 ? 'خارج کردن از آرشیو' : 'آرشیو کردن', () => pref({'archived': (it['arch'] ?? 0) == 1 ? 0 : 1}), false),
      ((it['mute'] ?? 0) == 1 ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, (it['mute'] ?? 0) == 1 ? 'صدادار کردن' : 'بی‌صدا کردن', () => pref({'muted': (it['mute'] ?? 0) == 1 ? 0 : 1}), false),
    ];
    if (t == 'p' && it['uid'] != meId) {
      acts.add((Icons.delete_outline, 'حذف گفتگو', () async {
        if (!await askConfirm(context, 'حذف گفتگو؟', 'تاریخچه این گفتگو از حساب شما پاک می‌شود.', 'حذف', danger: true)) return;
        final j = await Api.i.call('dm_delete', {'chat': 'p', 'peer': it['uid'], 'both': 0});
        if (mounted) toast(context, j['status'] == 'ok' ? 'حذف شد' : (j['message'] ?? 'خطا').toString());
        _tick(force: true);
      }, true));
    }
    if ((it['cid'] ?? 0) != 0 && it['role'] != 'owner') {
      acts.add((Icons.logout_rounded, 'ترک ${t == 'c' ? 'کانال' : 'گروه'}', () async {
        if (!await askConfirm(context, 'ترک گفتگو؟', 'دیگر پیام‌های این گفتگو را نمی‌بینید.', 'ترک', danger: true)) return;
        final j = await Api.i.call('chat_leave', {'cid': it['cid']});
        if (mounted) toast(context, j['status'] == 'ok' ? 'خارج شدید' : (j['message'] ?? 'خطا').toString());
        _tick(force: true);
      }, true));
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _sheet(chatName(it), acts);
  }

  void _sheet(String title, List<(IconData, String, VoidCallback, bool)> acts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: T.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: T.line, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(14), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
            for (final a in acts)
              ListTile(
                leading: Icon(a.$1, color: a.$4 ? const Color(0xFFE53935) : T.muted),
                title: Text(a.$2, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: a.$4 ? const Color(0xFFE53935) : T.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  a.$3();
                },
              ),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }

  /* ---------- دکمه‌ی مداد ---------- */

  void newMenu() {
    _sheet('گفتگوی جدید', [
      (Icons.person_outline, 'پیام جدید', () => setState(() => tab = 2), false),
      (Icons.groups_outlined, 'گروه جدید', () => _createChat('group'), false),
      (Icons.campaign_outlined, 'کانال جدید', () => _createChat('channel'), false),
    ]);
  }

  Future<void> _createChat(String kind) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: T.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(kind == 'channel' ? 'کانال جدید' : 'گروه جدید', style: const TextStyle(fontWeight: FontWeight.w800)),
          content: TextField(controller: c, maxLength: 60, autofocus: true, decoration: const InputDecoration(hintText: 'نام')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: TextStyle(color: T.muted))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('ساخت', style: TextStyle(color: T.accent, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final j = await Api.i.call('chat_create', {'kind': kind, 'name': c.text});
    if (!mounted) return;
    toast(context, j['status'] == 'ok' ? 'ساخته شد' : (j['message'] ?? 'خطا').toString());
    _tick(force: true);
  }

  /* ---------- استوری ---------- */

  Future<void> _addStory() async {
    if (!canStory) {
      toast(context, 'انتشار استوری مخصوص کاربران پریمیوم است.');
      return;
    }
    final x = await ImagePicker().pickMedia();
    if (x == null || !mounted) return;
    final cap = TextEditingController();
    var asCh = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, st) => AlertDialog(
            backgroundColor: T.panel,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('استوری جدید', style: TextStyle(fontWeight: FontWeight.w800)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: cap, maxLength: 300, decoration: const InputDecoration(hintText: 'توضیح (اختیاری)')),
              if (meAdmin) CheckboxListTile(contentPadding: EdgeInsets.zero, value: asCh, onChanged: (v) => st(() => asCh = v == true), title: const Text('انتشار به‌عنوان کانال')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: TextStyle(color: T.muted))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('انتشار', style: TextStyle(color: T.accent, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    toast(context, 'در حال ارسال…');
    final j = await Api.i.call('story_post', {'caption': cap.text, 'as_channel': asCh ? 1 : ''}, [await Api.i.file('file', x.path, name: x.name)]);
    if (!mounted) return;
    toast(context, j['status'] == 'ok' ? 'استوری منتشر شد' : (j['message'] ?? 'خطا').toString());
    _loadStories();
  }

  void _viewStories(Map<String, dynamic> g, int start) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => StoryViewerPage(group: g, start: start, channelName: items.where((i) => i['t'] == 'c' && i['main'] == true).map((i) => i['name'].toString()).firstOrNull ?? 'کانال', channelAvatar: items.where((i) => i['t'] == 'c' && i['main'] == true).map((i) => i['av'].toString()).firstOrNull ?? '')))
        .then((_) => _loadStories());
  }

  Widget _storiesRow() {
    final own = groups.where((g) => g['ch'] != true && g['uid'] == meId).firstOrNull;
    final mainCh = items.where((i) => i['t'] == 'c' && i['main'] == true).firstOrNull;
    Widget item({required Widget avatar, required String label, required VoidCallback onTap}) => GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 78,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              avatar,
              const SizedBox(height: 7),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    final children = <Widget>[
      item(
        label: 'استوری من',
        onTap: () => own != null ? _viewStories(own, 0) : _addStory(),
        avatar: SizedBox(
          width: 66,
          height: 66,
          child: Stack(clipBehavior: Clip.none, children: [
            Avatar(size: 66, uid: meId, ring: own != null ? 1 : 0, ringGap: T.hbar),
            Positioned(
              right: -1,
              bottom: -1,
              child: GestureDetector(
                onTap: _addStory,
                child: Container(width: 25, height: 25, decoration: BoxDecoration(color: T.accent, shape: BoxShape.circle, border: Border.all(color: T.hbar, width: 2.5)), child: const Icon(Icons.add, size: 14, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    ];
    for (final g in groups) {
      if (g['ch'] != true && g['uid'] == meId) continue;
      final ring = ((g['unseen'] ?? 0) as num) > 0 ? 2 : 1;
      final isCh = g['ch'] == true;
      children.add(item(
        label: isCh ? (mainCh?['name']?.toString() ?? 'کانال') : userName((g['uid'] as num).toInt()),
        onTap: () => _viewStories(g, (() {
          final it = (g['items'] as List);
          final i = it.indexWhere((x) => x['seen'] != true);
          return i < 0 ? 0 : i;
        })()),
        avatar: isCh
            ? Avatar(size: 66, img: mainCh?['av']?.toString(), label: mainCh?['name']?.toString(), color: const Color(0xFF3390EC), ring: ring, ringGap: T.hbar)
            : Avatar(size: 66, uid: (g['uid'] as num).toInt(), ring: ring, ringGap: T.hbar),
      ));
    }
    return Container(
      color: T.hbar,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      height: 112,
      child: Directionality(textDirection: TextDirection.ltr, child: ListView(scrollDirection: Axis.horizontal, children: children)),
    );
  }

  /* ---------- هدر و فیلترها ---------- */

  Widget _chatsHeader() {
    final top = MediaQuery.of(context).padding.top;
    if (searching) {
      return Container(
        color: T.hbar,
        padding: EdgeInsets.fromLTRB(6, top, 6, 0),
        height: 58 + top,
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            onPressed: () => setState(() {
              searching = false;
              q = '';
              _searchC.clear();
            }),
          ),
          Expanded(
            child: TextField(
              controller: _searchC,
              autofocus: true,
              onChanged: (v) => setState(() => q = v),
              style: const TextStyle(color: Colors.white, fontSize: 17),
              cursorColor: Colors.white,
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'جستجوی گفتگوها', hintStyle: TextStyle(color: Color(0xB3FFFFFF))),
            ),
          ),
        ]),
      );
    }
    Widget ib(IconData i, VoidCallback f) => SizedBox(width: 44, height: 44, child: IconButton(padding: EdgeInsets.zero, icon: Icon(i, color: Colors.white, size: 22), onPressed: f));
    return Container(
      color: T.hbar,
      padding: EdgeInsets.fromLTRB(10, top + 10, 10, 6),
      child: Row(children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            ib(Icons.menu_rounded, () => setState(() => tab = 1)),
            ib(Icons.search_rounded, () => setState(() => searching = true)),
            ib(Icons.more_vert_rounded, () => _sheet('گزینه‌ها', [
                  (Icons.refresh_rounded, 'بروزرسانی', () => _tick(force: true), false),
                  (Icons.bookmark_border_rounded, 'پیام‌های ذخیره‌شده', () => openUserChat(meId), false),
                  if (meAdmin) (Icons.admin_panel_settings_outlined, 'پنل مدیریت', () => launchUrl(Uri.parse('${Api.i.base}admin.php'), mode: LaunchMode.externalApplication), false),
                ])),
          ]),
        ),
        const Spacer(),
        const Directionality(textDirection: TextDirection.ltr, child: Text('Parvaz', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: .3))),
      ]),
    );
  }

  Widget _filters() {
    const hf = [('all', 'همه'), ('unread', 'خوانده‌نشده'), ('c', 'کانال‌ها'), ('g', 'گروه‌ها'), ('p', 'شخصی')];
    return Container(
      color: T.hbar,
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final f in hf)
            GestureDetector(
              onTap: () => setState(() => filter = f.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: filter == f.$1 ? Colors.white : Colors.transparent, width: 3))),
                child: Row(children: [
                  Text(f.$2, style: TextStyle(color: filter == f.$1 ? Colors.white : const Color(0xBDFFFFFF), fontSize: 16.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: filter == f.$1 ? Colors.white : const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(12)),
                    child: Text(fa(_count(f.$1)), style: TextStyle(color: filter == f.$1 ? T.hbar : Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  /* ---------- ردیف گفتگو ---------- */

  Widget _row(Map<String, dynamic> it) {
    final t = it['t'].toString();
    final uid = (it['uid'] as num?)?.toInt() ?? 0;
    final u = t == 'p' ? users[uid] : null;
    final isSelf = t == 'p' && uid == meId;
    final st = (u != null && !isSelf) ? ((u['st'] ?? 0) as num).toInt() : 0;
    Widget av;
    if (isSelf) {
      av = const Avatar(size: 54, icon: Icons.bookmark, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF59B6FF), Color(0xFF3390EC)]));
    } else if (t == 'p') {
      av = GestureDetector(onTap: st > 0 ? () => _openUserStory(uid) : () => openItem(it), child: Avatar(size: 54, uid: uid, ring: st, online: isOnline(u)));
    } else {
      av = Avatar(size: 54, img: (it['av'] ?? '').toString(), label: (it['name'] ?? '').toString(), color: t == 'c' ? const Color(0xFF3390EC) : const Color(0xFF2A9D8F));
    }
    final lt = _lastText(it);
    final unread = ((it['unread'] ?? 0) as num).toInt();
    final muted = (it['mute'] ?? 0) == 1;
    final last = it['last'];
    return InkWell(
      onTap: () => openItem(it),
      onLongPress: () => chatMenu(it),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x1F7F7F7F)))),
        child: Row(children: [
          av,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Row(children: [
                    Flexible(child: Text(chatName(it), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17.5))),
                    if (t == 'p' && !isSelf) NameBadge(u) else if (t != 'p' && it['ver'] == true) const VerifiedTick(),
                    if (muted) Padding(padding: const EdgeInsetsDirectional.only(start: 5), child: Icon(Icons.notifications_off, size: 13, color: T.muted)),
                  ]),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if ((it['pin'] ?? 0) == 1) Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1), decoration: BoxDecoration(color: T.hover, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.push_pin, size: 12, color: T.muted)),
                    if (last is Map) Text(listTime((last['ts'] as num).toInt()), style: TextStyle(fontSize: 12.5, color: T.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      if (lt.$1.isNotEmpty) TextSpan(text: '${lt.$1}: ', style: TextStyle(color: T.accent, fontWeight: FontWeight.w600)),
                      TextSpan(text: lt.$2),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: T.muted, fontSize: 15),
                  ),
                ),
                if (unread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: muted ? const Color(0xFFA3ACB6) : T.accent, borderRadius: BorderRadius.circular(11)),
                    child: Text(fa(unread), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _openUserStory(int uid) async {
    final j = await Api.i.call('stories_list');
    if (j['status'] != 'ok' || !mounted) return;
    mergeUsers(j['users']);
    final gs = (j['groups'] as List).map(_m).where((g) => g['ch'] != true && g['uid'] == uid).toList();
    if (gs.isEmpty) return;
    final it = gs.first['items'] as List;
    final i = it.indexWhere((x) => x['seen'] != true);
    _viewStories(gs.first, i < 0 ? 0 : i);
  }

  /* ---------- زبانه‌ها ---------- */

  Widget _chatsTab() {
    final list = sorted;
    final archd = items.where((i) => (i['arch'] ?? 0) == 1).toList();
    return Column(children: [
      _chatsHeader(),
      Expanded(
        child: CustomScrollView(slivers: [
          if (!searching) SliverToBoxAdapter(child: _storiesRow()),
          SliverPersistentHeader(pinned: true, delegate: _PinnedBar(52, _filters())),
          if (filter == 'arch')
            SliverToBoxAdapter(
              child: ListTile(leading: Icon(Icons.arrow_forward_rounded, color: T.accent), title: const Text('بازگشت به گفتگوها', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('گفتگوهای آرشیوشده'), onTap: () => setState(() => filter = 'all')),
            )
          else if (archd.isNotEmpty && q.trim().isEmpty)
            SliverToBoxAdapter(
              child: ListTile(leading: Icon(Icons.archive_outlined, color: T.muted), title: const Text('آرشیو', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${fa(archd.length)} گفتگو'), onTap: () => setState(() => filter = 'arch')),
            ),
          if (list.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(padding: const EdgeInsets.only(bottom: 120), child: Text(!_loaded ? 'در حال بارگذاری…' : (filter == 'arch' ? 'آرشیو خالی است' : 'گفتگویی پیدا نشد'), style: TextStyle(color: T.muted)))))
          else
            SliverList(delegate: SliverChildBuilderDelegate((c, i) => _row(list[i]), childCount: list.length)),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ]),
      ),
    ]);
  }

  Widget _titleBar(String t) => Padding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 4),
        child: Align(alignment: Alignment.centerRight, child: Text(t, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
      );

  Future<void> _loadContacts() async {
    if (contactsBusy) return;
    contactsBusy = true;
    final qq = _cq.text.trim();
    final j = await Api.i.call(qq.isEmpty ? 'contacts_list' : 'members', {'q': qq, 'offset': 0});
    contactsBusy = false;
    if (j['status'] == 'ok' && mounted) {
      mergeUserList(j['list']);
      setState(() => contacts = (j['list'] as List).map(_m).toList());
    }
  }

  Widget _contactsTab() {
    if (contacts.isEmpty && !contactsBusy && _cq.text.isEmpty) _loadContacts();
    return Column(children: [
      _titleBar('مخاطبین'),
      Container(
        height: 56,
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(color: T.hover, borderRadius: BorderRadius.circular(28)),
        child: Row(children: [
          Icon(Icons.search_rounded, color: T.muted),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _cq, onChanged: (_) => _loadContacts(), style: const TextStyle(fontSize: 16.5), decoration: InputDecoration(border: InputBorder.none, hintText: 'جستجوی کاربران', hintStyle: TextStyle(color: T.muted)))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: contacts.length,
          itemBuilder: (c, i) {
            final u = contacts[i];
            final id = (u['id'] as num).toInt();
            final uu = users[id];
            return ListTile(
              onTap: () => openUserChat(id),
              leading: Avatar(size: 48, uid: id, ring: ((uu?['st'] ?? 0) as num).toInt(), online: isOnline(uu)),
              title: Row(children: [Flexible(child: Text(userName(id), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5))), NameBadge(uu)]),
              subtitle: Text(presence(uu), style: TextStyle(color: isOnline(uu) ? T.accent : T.muted, fontSize: 13.5)),
            );
          },
        ),
      ),
    ]);
  }

  static const _themeNames = [('default', 'پیش‌فرض'), ('tg', 'کلاسیک'), ('dark', 'تاریک'), ('midnight', 'نیمه‌شب'), ('purple', 'بنفش'), ('blue', 'آبی'), ('ocean', 'اقیانوس'), ('sunset', 'غروب'), ('forest', 'جنگل'), ('rose', 'رز'), ('gold', 'طلایی ⭐'), ('neon', 'نئون ⭐')];

  Future<void> _pickTheme() async {
    _sheet('ظاهر برنامه', [
      for (final t in _themeNames)
        (Icons.palette_outlined, t.$2, () async {
          final j = await Api.i.call('set_theme', {'theme': t.$1});
          if (!mounted) return;
          if (j['status'] != 'ok') {
            toast(context, (j['message'] ?? 'خطا').toString());
            return;
          }
          final b = await Api.i.boot();
          if (b['status'] == 'ok') applyCfg(b);
        }, false),
    ]);
  }

  Future<void> _editProfile() async {
    final n = TextEditingController(text: (ME['name'] ?? '').toString());
    final b = TextEditingController(text: (ME['bio'] ?? '').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: T.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('ویرایش مشخصات', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: n, maxLength: 30, decoration: const InputDecoration(labelText: 'نام')),
            TextField(controller: b, maxLength: 200, decoration: const InputDecoration(labelText: 'درباره من')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: TextStyle(color: T.muted))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('ذخیره', style: TextStyle(color: T.accent, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final j = await Api.i.call('update_profile', {'username': n.text, 'bio': b.text});
    if (!mounted) return;
    if (j['status'] == 'ok') {
      final bt = await Api.i.boot();
      if (bt['status'] == 'ok') applyCfg(bt);
      setState(() {});
      toast(context, 'ذخیره شد');
    } else {
      toast(context, (j['message'] ?? 'خطا').toString());
    }
  }

  Future<void> _setPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 88);
    if (x == null || !mounted) return;
    final j = await Api.i.call('upload_avatar', null, [await Api.i.file('image', x.path, name: x.name)]);
    if (!mounted) return;
    if (j['status'] == 'ok') {
      ME['pic'] = j['pic'];
      users[meId] = {...(users[meId] ?? {}), 'p': j['pic']};
      await CachedNetworkImage.evictFromCache(Api.i.url('uploads/${j['pic']}'));
      setState(() {});
      toast(context, 'عکس پروفایل تغییر کرد');
    } else {
      toast(context, (j['message'] ?? 'خطا').toString());
    }
  }

  Future<void> _logout() async {
    if (!await askConfirm(context, 'خروج از حساب؟', 'برای ورود دوباره، نام کاربری و رمز لازم است.', 'خروج', danger: true)) return;
    await Api.i.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  Widget _card(List<Widget> rows) => Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        decoration: BoxDecoration(color: T.panel, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 1))]),
        child: Column(children: rows),
      );

  Widget _prow(IconData i, Color c, String t, VoidCallback f) => ListTile(
        onTap: f,
        leading: Icon(i, color: c),
        title: Text(t, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_left_rounded, color: T.muted),
      );

  Widget _settingsTab() => ListView(padding: const EdgeInsets.only(bottom: 120), children: [
        _titleBar('تنظیمات'),
        _card([
          ListTile(
            leading: Avatar(size: 52, uid: meId),
            title: Row(children: [Flexible(child: Text((ME['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))), NameBadge(users[meId])]),
            subtitle: Text((ME['bio'] ?? '').toString().isEmpty ? (mePremium ? 'کاربر پریمیوم ⭐' : 'کاربر') : ME['bio'].toString(), style: TextStyle(color: T.muted)),
            onTap: _editProfile,
          ),
        ]),
        _card([
          _prow(Icons.edit_outlined, const Color(0xFF3390EC), 'ویرایش مشخصات', _editProfile),
          _prow(Icons.palette_outlined, const Color(0xFFE67E22), 'ظاهر و پس‌زمینه', _pickTheme),
          _prow(Icons.bookmark_border_rounded, const Color(0xFF3390EC), 'پیام‌های ذخیره‌شده', () => openUserChat(meId)),
        ]),
        if (meAdmin) _card([_prow(Icons.workspace_premium_outlined, const Color(0xFFF5B301), 'پنل مدیریت', () => launchUrl(Uri.parse('${Api.i.base}admin.php'), mode: LaunchMode.externalApplication))]),
        _card([_prow(Icons.logout_rounded, const Color(0xFFE53935), 'خروج از حساب', _logout)]),
      ]);

  Widget _profileTab() {
    final u = users[meId];
    Widget act(IconData i, String t, VoidCallback f) => Expanded(
          child: GestureDetector(
            onTap: f,
            child: Container(
              height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(color: T.panel, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 1))]),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: T.accent, size: 24), const SizedBox(height: 6), Text(t, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))]),
            ),
          ),
        );
    Widget info(String v, String l) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: const TextStyle(fontSize: 16.5)), const SizedBox(height: 2), Text(l, style: TextStyle(color: T.muted, fontSize: 13))]),
        );
    final handle = (ME['handle'] ?? '').toString();
    return ListView(padding: const EdgeInsets.only(bottom: 120), children: [
      SizedBox(height: MediaQuery.of(context).padding.top + 24),
      Center(child: Avatar(size: 104, uid: meId, ring: groups.any((g) => g['ch'] != true && g['uid'] == meId) ? 1 : 0)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text((ME['name'] ?? '').toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), NameBadge(u, size: 20)]),
      const SizedBox(height: 2),
      Center(child: Text('آنلاین', style: TextStyle(color: T.accent, fontSize: 14))),
      const SizedBox(height: 18),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 9), child: Row(children: [act(Icons.camera_alt_outlined, 'تنظیم عکس', _setPhoto), act(Icons.edit_outlined, 'ویرایش اطلاعات', _editProfile), act(Icons.settings_outlined, 'تنظیمات', () => setState(() => tab = 1))])),
      const SizedBox(height: 14),
      _card([
        info((ME['bio'] ?? '').toString().isEmpty ? '—' : ME['bio'].toString(), 'درباره من'),
        Divider(height: 1, color: T.line),
        info(handle.isEmpty ? (ME['name'] ?? '').toString() : '@$handle', 'نام کاربری'),
        Divider(height: 1, color: T.line),
        info(mePremium ? 'پریمیوم ⭐' : 'عادی', 'نوع حساب'),
      ]),
    ]);
  }

  /* ---------- نوار پایین شناور ---------- */

  Widget _navBtn(int i, Widget icon, String label, {int badge = 0}) {
    final on = tab == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        tab = i;
        if (i == 2) _loadContacts();
      }),
      child: Container(
        constraints: const BoxConstraints(minWidth: 68),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: on ? Color.lerp(Colors.transparent, T.accent, .15) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            height: 28,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              icon,
              if (badge > 0)
                Positioned(
                  top: -2,
                  right: -12,
                  child: Container(constraints: const BoxConstraints(minWidth: 19), height: 19, padding: const EdgeInsets.symmetric(horizontal: 5), alignment: Alignment.center, decoration: BoxDecoration(color: T.accent, borderRadius: BorderRadius.circular(10)), child: Text(fa(badge > 999 ? 999 : badge), style: const TextStyle(color: Colors.white, fontSize: 11))),
                ),
            ]),
          ),
          Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? T.accent : T.text)),
        ]),
      ),
    );
  }

  Widget _bottomNav() {
    Color c(int i) => tab == i ? T.accent : T.text;
    return Positioned(
      left: 14,
      right: 14,
      bottom: 10 + MediaQuery.of(context).padding.bottom,
      child: Container(
        height: 66,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: T.panel, borderRadius: BorderRadius.circular(34), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 4))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _navBtn(0, Avatar(size: 28, uid: meId), 'پروفایل'),
          _navBtn(1, Icon(Icons.settings, size: 24, color: c(1)), 'تنظیمات'),
          _navBtn(2, Icon(Icons.account_circle_outlined, size: 25, color: c(2)), 'مخاطبین'),
          _navBtn(3, Icon(Icons.chat_bubble, size: 24, color: c(3)), 'گفتگوها', badge: totalUnread),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onChats = tab == 3;
    final Widget body = switch (tab) {
      0 => _profileTab(),
      1 => _settingsTab(),
      2 => _contactsTab(),
      _ => _chatsTab(),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: onChats || T.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: onChats || T.dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: T.bg,
        systemNavigationBarIconBrightness: T.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: T.bg,
        body: Stack(children: [
          Positioned.fill(child: body),
          if (onChats)
            Positioned(
              left: 18,
              bottom: 98 + MediaQuery.of(context).padding.bottom,
              child: GestureDetector(
                onTap: newMenu,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: T.accent, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x73 << 0 == 0 ? 0 : 0x7333 90EC), blurRadius: 18, offset: Offset(0, 6))]),
                  child: const Icon(Icons.edit, color: Colors.white, size: 24),
                ),
              ),
            ),
          _bottomNav(),
        ]),
      ),
    );
  }
}

class _PinnedBar extends SliverPersistentHeaderDelegate {
  final double h;
  final Widget child;
  _PinnedBar(this.h, this.child);
  @override
  double get minExtent => h;
  @override
  double get maxExtent => h;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  bool shouldRebuild(covariant _PinnedBar old) => true;
}

/* ===================== نمایشگر استوری ===================== */

class StoryViewerPage extends StatefulWidget {
  final Map<String, dynamic> group;
  final int start;
  final String channelName;
  final String channelAvatar;
  const StoryViewerPage({super.key, required this.group, required this.start, this.channelName = 'کانال', this.channelAvatar = ''});
  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late List<Map<String, dynamic>> items;
  int idx = 0;
  VideoPlayerController? vc;

  bool get isCh => widget.group['ch'] == true;

  @override
  void initState() {
    super.initState();
    items = (widget.group['items'] as List).map(_m).toList();
    idx = widget.start.clamp(0, items.isEmpty ? 0 : items.length - 1);
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 5))..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    if (items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    vc?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _ac.stop();
    _ac.reset();
    final old = vc;
    vc = null;
    old?.dispose();
    if (mounted) setState(() {});
    final it = items[idx];
    if (it['mine'] != true && it['seen'] != true) {
      it['seen'] = true;
      Api.i.call('story_view', {'id': it['id']});
    }
    if (it['kind'] == 'video') {
      final c = VideoPlayerController.networkUrl(Uri.parse(Api.i.url(it['file'].toString())));
      vc = c;
      try {
        await c.initialize();
      } catch (_) {
        if (vc == c) _next();
        return;
      }
      if (!mounted || vc != c) return;
      final d = c.value.duration;
      _ac.duration = d > Duration.zero ? d : const Duration(seconds: 8);
      c.play();
      _ac.forward(from: 0);
      setState(() {});
    } else {
      _ac.duration = const Duration(seconds: 5);
      _ac.forward(from: 0);
    }
  }

  void _next() {
    if (!mounted) return;
    if (idx >= items.length - 1) {
      Navigator.of(context).maybePop();
    } else {
      idx++;
      _load();
    }
  }

  void _prev() {
    if (idx > 0) idx--;
    _load();
  }

  Future<void> _delete() async {
    _ac.stop();
    vc?.pause();
    final ok = await askConfirm(context, 'حذف استوری؟', 'این استوری برای همه حذف می‌شود.', 'حذف', danger: true);
    if (!ok) {
      _ac.forward();
      vc?.play();
      return;
    }
    await Api.i.call('story_delete', {'id': items[idx]['id']});
    if (!mounted) return;
    items.removeAt(idx);
    if (items.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    if (idx >= items.length) idx = items.length - 1;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Scaffold(backgroundColor: Colors.black);
    final it = items[idx];
    final uid = (widget.group['uid'] as num).toInt();
    final name = isCh ? widget.channelName : userName(uid);
    final mine = it['mine'] == true;
    Widget media;
    if (it['kind'] == 'video') {
      media = (vc != null && vc!.value.isInitialized) ? Center(child: AspectRatio(aspectRatio: vc!.value.aspectRatio, child: VideoPlayer(vc!))) : const Center(child: CircularProgressIndicator(color: Colors.white));
    } else {
      media = CachedNetworkImage(imageUrl: Api.i.url(it['file'].toString()), fit: BoxFit.contain, width: double.infinity, height: double.infinity, placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)), errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)));
    }
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(children: [
          Positioned.fill(child: media),
          Positioned.fill(
            child: Row(children: [
              Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _next)),
              Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _prev)),
            ]),
          ),
          Positioned(
            top: top + 8,
            left: 8,
            right: 8,
            child: AnimatedBuilder(
              animation: _ac,
              builder: (_, __) => Row(children: [
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: const Color(0x59FFFFFF), borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(alignment: Alignment.centerRight, widthFactor: i < idx ? 1 : (i == idx ? _ac.value : 0), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))),
                    ),
                  ),
              ]),
            ),
          ),
          Positioned(
            top: top + 20,
            left: 8,
            right: 8,
            child: Row(children: [
              isCh ? Avatar(size: 38, img: widget.channelAvatar, label: widget.channelName, color: const Color(0xFF3390EC)) : Avatar(size: 38, uid: uid),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)), Text(listTime((it['ts'] as num).toInt()), style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12))])),
              if (mine || meAdmin) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: _delete),
              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
            ]),
          ),
          if ((it['cap'] ?? '').toString().isNotEmpty)
            Positioned(left: 0, right: 0, bottom: 0, child: Container(padding: EdgeInsets.fromLTRB(18, 24, 18, 24 + MediaQuery.of(context).padding.bottom), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xA6000000)])), child: Text(it['cap'].toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.7)))),
          if (mine || meAdmin) Positioned(left: 16, bottom: 14 + MediaQuery.of(context).padding.bottom, child: Row(children: [const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 18), const SizedBox(width: 5), Text(fa((it['views'] ?? 0) as num), style: const TextStyle(color: Colors.white70))])),
        ]),
      ),
    );
  }
}
