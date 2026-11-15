import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'api_service.dart';
import 'common.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
Map<String, dynamic> _m(dynamic e) => Map<String, dynamic>.from(e as Map);

TextDirection _dirOf(String s) {
  final m = RegExp(r'[A-Za-z\u0600-\u06FF]').firstMatch(s);
  if (m == null) return TextDirection.rtl;
  return RegExp(r'[A-Za-z]').hasMatch(m[0]!) ? TextDirection.ltr : TextDirection.rtl;
}

/// صفحه‌ی گفتگو (گروه / کانال / خصوصی) — پولینگ با اکشن sync مثل سایت.
class ChatScreen extends StatefulWidget {
  final String chat; // g | c | p
  final int cid;
  final int peer;
  final String title;
  final String avatar;
  final bool verified;
  final String role;
  const ChatScreen({super.key, required this.chat, this.cid = 0, this.peer = 0, this.title = '', this.avatar = '', this.verified = false, this.role = ''});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final List<Map<String, dynamic>> msgs = [];
  Map<int, List<List<dynamic>>> reacts = {};
  Map<int, Map<String, dynamic>> polls = {};
  int lastId = 0, minId = 0, readUpto = 0, total = 0, online = 0, subs = 0, _tmp = 0;
  bool more = false, loadingOlder = false, inited = false, lock = false, muted = false, _busy = false, _active = true;
  String rsig = '', psig = '';
  List<String> typing = [];
  List<Map<String, dynamic>> pins = [];
  Map<String, dynamic>? cm;
  String title = '';
  String avatar = '';
  bool verified = false;
  int slow = 0;
  DateTime _lastSync = DateTime.now(), _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  Map<String, dynamic>? replyTo;
  int? editId;
  final Set<int> _viewed = {};

  bool get isG => widget.chat == 'g';
  bool get isC => widget.chat == 'c';
  bool get isP => widget.chat == 'p';
  String get role => (cm?['role'] ?? widget.role).toString();
  bool get canMod => meAdmin || role == 'owner' || role == 'admin';

  Map<String, dynamic> _sp() => {'chat': widget.chat, 'cid': widget.cid, 'peer': widget.peer};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    title = widget.title;
    avatar = widget.avatar;
    verified = widget.verified;
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _older();
    });
    _sync(init: true);
    _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _active = s == AppLifecycleState.resumed;
    if (_active) _sync();
  }

  /* ---------- همگام‌سازی ---------- */

  Future<void> _sync({bool init = false}) async {
    if (_busy || !_active || !mounted) return;
    _busy = true;
    final real = msgs.where((m) => _i(m['id']) > 0).toList();
    final gap = DateTime.now().difference(_lastSync).inSeconds + 3;
    final j = await Api.i.call('sync', {
      ..._sp(),
      'init': init ? '1' : '0',
      'last_id': lastId,
      'min_id': minId,
      'cnt': real.length,
      'gap': gap < 3 ? 3 : gap,
      'rsig': rsig,
      'psig': psig,
    });
    _busy = false;
    if (!mounted || j['status'] != 'ok') return;
    _lastSync = DateTime.now();
    mergeUsers(j['users']);
    setState(() {
      final nw = (j['new'] as List? ?? []).map(_m).toList();
      if (j['init'] == true) {
        msgs
          ..clear()
          ..addAll(nw);
        minId = _i(j['min_id']);
        more = j['more'] == true;
        inited = true;
      } else {
        final have = msgs.map((m) => _i(m['id'])).toSet();
        for (final m in nw) {
          if (!have.contains(_i(m['id']))) msgs.add(m);
        }
        msgs.removeWhere((m) => _i(m['id']) < 0 && nw.any((n) => n['uid'] == m['uid'] && n['text'] == m['text'] && n['type'] == m['type']));
        final alive = j['alive'];
        if (alive is List) {
          final a = alive.map(_i).toSet();
          msgs.removeWhere((m) => _i(m['id']) > 0 && _i(m['id']) >= minId && _i(m['id']) <= lastId && !a.contains(_i(m['id'])));
        }
        final ed = j['edited'];
        if (ed is List) {
          for (final e in ed) {
            final i = msgs.indexWhere((m) => _i(m['id']) == _i(e['id']));
            if (i >= 0) {
              msgs[i]['text'] = e['text'];
              msgs[i]['edited'] = 1;
            }
          }
        }
      }
      msgs.sort((a, b) {
        final x = _i(a['id']), y = _i(b['id']);
        if (x < 0 && y < 0) return y.compareTo(x);
        if (x < 0) return 1;
        if (y < 0) return -1;
        return x.compareTo(y);
      });
      final ids = msgs.map((m) => _i(m['id'])).where((i) => i > 0);
      lastId = ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b);
      if (j['reacts'] != null) {
        reacts = {};
        (j['reacts'] as Map).forEach((k, v) {
          reacts[int.parse(k.toString())] = (v as List).map((e) => List<dynamic>.from(e as List)).toList();
        });
      }
      if (j['rsig'] != null) rsig = j['rsig'].toString();
      if (j['polls'] != null) {
        polls = {};
        (j['polls'] as Map).forEach((k, v) => polls[int.parse(k.toString())] = _m(v));
      }
      if (j['psig'] != null) psig = j['psig'].toString();
      typing = (j['typing'] as List? ?? []).map((t) => (t['act'] == 'voice' ? '${t['n']} در حال ضبط ویس' : '${t['n']} در حال نوشتن')).toList();
      pins = (j['pins'] as List? ?? []).map(_m).toList();
      final f = j['flags'];
      if (f is Map) {
        lock = f['lock'] == true;
        muted = f['muted'] == true;
      }
      slow = _i(j['slow']);
      if (j['cm'] is Map) {
        cm = _m(j['cm']);
        title = (cm!['name'] ?? title).toString();
        avatar = (cm!['avatar'] ?? avatar).toString();
        verified = cm!['verified'] == true;
      }
      if (isG) {
        total = _i(j['total']);
        online = _i(j['online']);
      }
      if (isC) {
        final ch = j['chmeta'];
        if (ch is Map) {
          subs = _i(ch['subs']);
          if (widget.cid == 0) {
            title = (ch['name'] ?? title).toString();
            if ((ch['avatar'] ?? '').toString().isNotEmpty) avatar = ch['avatar'].toString();
          }
        }
        if (cm != null) subs = _i(cm!['members']);
      }
      if (isP) readUpto = _i(j['read_upto']);
    });
    if (isC) _markViews();
  }

  void _markViews() {
    final ids = msgs.map((m) => _i(m['id'])).where((i) => i > 0 && !_viewed.contains(i)).take(60).toList();
    if (ids.isEmpty) return;
    _viewed.addAll(ids);
    Api.i.call('view', {'ids': ids});
  }

  Future<void> _older() async {
    if (loadingOlder || !more || minId <= 0) return;
    loadingOlder = true;
    final j = await Api.i.call('older', {..._sp(), 'before': minId});
    loadingOlder = false;
    if (!mounted || j['status'] != 'ok') return;
    mergeUsers(j['users']);
    setState(() {
      final have = msgs.map((m) => _i(m['id'])).toSet();
      for (final m in (j['msgs'] as List).map(_m)) {
        if (!have.contains(_i(m['id']))) msgs.add(m);
      }
      msgs.sort((a, b) => _i(a['id']).compareTo(_i(b['id'])));
      minId = _i(j['min_id']);
      more = j['more'] == true;
      if (j['reacts'] is Map) {
        (j['reacts'] as Map).forEach((k, v) => reacts[int.parse(k.toString())] = (v as List).map((e) => List<dynamic>.from(e as List)).toList());
      }
    });
  }

  /* ---------- ارسال ---------- */

  Future<void> _sendText() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    if (editId != null) {
      final id = editId!;
      setState(() => editId = null);
      _input.clear();
      final j = await Api.i.call('edit', {..._sp(), 'id': id, 'text': t});
      if (!mounted) return;
      if (j['status'] != 'ok') toast(context, (j['message'] ?? 'خطا').toString());
      _sync();
      return;
    }
    final reply = replyTo;
    _input.clear();
    final tid = -(++_tmp);
    setState(() {
      replyTo = null;
      msgs.add({'id': tid, 'uid': meId, 'text': t, 'type': 'text', 'file': null, 'rid': reply == null ? 0 : _i(reply['id']), 'edited': 0, 'fwd': null, 'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'rt': reply?['text'], 'ru': reply?['uid'], 'rty': reply?['type'], 'views': 0, 'pending': true});
    });
    final j = await Api.i.call('send', {..._sp(), 'type': 'text', 'message': t, 'reply_id': reply == null ? '' : _i(reply['id'])});
    if (!mounted) return;
    setState(() {
      msgs.removeWhere((m) => _i(m['id']) == tid);
      if (j['status'] == 'ok' && j['msg'] is Map) {
        mergeUsers(j['users']);
        final nm = _m(j['msg']);
        if (!msgs.any((m) => _i(m['id']) == _i(nm['id']))) msgs.add(nm);
        msgs.sort((a, b) => _i(a['id']).compareTo(_i(b['id'])));
        lastId = msgs.map((m) => _i(m['id'])).reduce((a, b) => a > b ? a : b);
      }
    });
    if (j['status'] != 'ok') {
      _input.text = t;
      toast(context, (j['message'] ?? 'ارسال نشد').toString());
    }
  }

  Future<void> _attach(ImageSource? src) async {
    final picker = ImagePicker();
    XFile? x;
    if (src == ImageSource.camera) {
      x = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
    } else {
      x = await picker.pickMedia(imageQuality: 85, maxWidth: 1600);
    }
    if (x == null || !mounted) return;
    final ext = x.name.toLowerCase().split('.').last;
    final isVideo = ['mp4', 'mov', 'webm', '3gp', 'mkv'].contains(ext);
    final isGif = ext == 'gif';
    final type = isVideo ? 'video' : (isGif ? 'gif' : 'image');
    final reply = replyTo;
    setState(() => replyTo = null);
    toast(context, 'در حال ارسال…');
    final j = await Api.i.call('send', {..._sp(), 'type': type, 'message': _input.text.trim(), 'reply_id': reply == null ? '' : _i(reply['id'])}, [await Api.i.file('file', x.path, name: x.name)]);
    if (!mounted) return;
    if (j['status'] == 'ok') {
      _input.clear();
      _sync();
    } else {
      toast(context, (j['message'] ?? 'ارسال نشد').toString());
    }
  }

  void _attachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: T.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF8E44AD)), title: const Text('عکس / ویدیو / گیف'), onTap: () { Navigator.pop(ctx); _attach(null); }),
            ListTile(leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFF2D9CDB)), title: const Text('دوربین'), onTap: () { Navigator.pop(ctx); _attach(ImageSource.camera); }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _onChanged(String v) {
    setState(() {});
    if (v.isNotEmpty && DateTime.now().difference(_lastTyping).inSeconds >= 3) {
      _lastTyping = DateTime.now();
      Api.i.call('typing', {..._sp(), 'act': 'typing'});
    }
  }

  /* ---------- منوی پیام ---------- */

  Future<void> _msgMenu(Map<String, dynamic> m) async {
    if (_i(m['id']) <= 0) return;
    HapticFeedback.mediumImpact();
    final mine = _i(m['uid']) == meId;
    final id = _i(m['id']);
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];
    final acts = <(IconData, String, VoidCallback, bool)>[];
    if (m['type'] != 'service') {
      acts.add((Icons.reply_rounded, 'پاسخ', () => setState(() { replyTo = m; editId = null; _focus.requestFocus(); }), false));
      if ((m['text'] ?? '').toString().isNotEmpty && m['type'] != 'poll') {
        acts.add((Icons.copy_rounded, 'کپی', () { Clipboard.setData(ClipboardData(text: m['text'].toString())); toast(context, 'کپی شد'); }, false));
      }
      if (mine && m['type'] == 'text') {
        acts.add((Icons.edit_outlined, 'ویرایش', () => setState(() { editId = id; replyTo = null; _input.text = m['text'].toString(); _focus.requestFocus(); }), false));
      }
    }
    if (mine || (canMod && !isP)) {
      acts.add((Icons.delete_outline, 'حذف', () async {
        if (!await askConfirm(context, 'حذف پیام؟', 'این پیام حذف می‌شود.', 'حذف', danger: true)) return;
        final j = await Api.i.call('delete', {..._sp(), 'ids': [id]});
        if (!mounted) return;
        if (j['status'] == 'ok') {
          setState(() => msgs.removeWhere((x) => _i(x['id']) == id));
        } else {
          toast(context, (j['message'] ?? 'خطا').toString());
        }
      }, true));
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: T.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            if (m['type'] != 'service' && !isP || (isP && m['type'] != 'service'))
              SizedBox(
                height: 52,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
                  for (final e in emojis)
                    GestureDetector(
                      onTap: () { Navigator.pop(ctx); _react(id, e); },
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Center(child: Text(e, style: const TextStyle(fontSize: 28)))),
                    ),
                ]),
              ),
            for (final a in acts)
              ListTile(
                leading: Icon(a.$1, color: a.$4 ? const Color(0xFFE53935) : T.muted),
                title: Text(a.$2, style: TextStyle(fontWeight: FontWeight.w600, color: a.$4 ? const Color(0xFFE53935) : T.text)),
                onTap: () { Navigator.pop(ctx); a.$3(); },
              ),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }

  Future<void> _react(int id, String e) async {
    setState(() {
      final l = reacts[id] ?? [];
      final mineIdx = l.indexWhere((x) => _i(x[1]) == meId);
      final same = mineIdx >= 0 && l[mineIdx][0] == e;
      if (mineIdx >= 0) l.removeAt(mineIdx);
      if (!same) l.add([e, meId]);
      reacts[id] = l;
    });
    final j = await Api.i.call('react', {..._sp(), 'id': id, 'emoji': e});
    if (j['status'] != 'ok' && mounted) toast(context, (j['message'] ?? 'خطا').toString());
    rsig = '';
    _sync();
  }

  Future<void> _vote(int id, int opt) async {
    final j = await Api.i.call('poll_vote', {..._sp(), 'id': id, 'opt': opt});
    if (j['status'] != 'ok' && mounted) toast(context, (j['message'] ?? 'خطا').toString());
    psig = '';
    _sync();
  }

  /* ---------- ساخت رابط ---------- */

  Widget _topBar() {
    final top = MediaQuery.of(context).padding.top;
    String sub;
    var subTyping = false;
    if (typing.isNotEmpty) {
      sub = typing.first;
      subTyping = true;
    } else if (isP) {
      sub = widget.peer == meId ? 'فقط خودتان می‌بینید' : presence(users[widget.peer]);
    } else if (isG) {
      sub = '${fa(total)} عضو${online > 0 ? '، ${fa(online)} آنلاین' : ''}';
    } else {
      sub = subs > 0 ? '${fa(subs)} مشترک' : 'کانال';
    }
    final u = users[widget.peer];
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 4, 8, 6),
      decoration: BoxDecoration(color: T.panel, boxShadow: [BoxShadow(color: T.line, offset: const Offset(0, 1))]),
      child: Row(children: [
        IconButton(icon: Icon(Icons.arrow_forward_rounded, color: T.muted), onPressed: () => Navigator.of(context).maybePop()),
        if (isP && widget.peer == meId)
          const Avatar(size: 42, icon: Icons.bookmark, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF59B6FF), Color(0xFF3390EC)]))
        else if (isP)
          Avatar(size: 42, uid: widget.peer, online: isOnline(u), ringGap: T.panel)
        else
          Avatar(size: 42, img: avatar, label: title, color: isC ? const Color(0xFF3390EC) : const Color(0xFF2A9D8F)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5))),
              if (isP && widget.peer != meId) NameBadge(u) else if (!isP && verified) const VerifiedTick(),
            ]),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: subTyping || (isP && isOnline(u)) ? T.accent : T.muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _pinBar() {
    if (pins.isEmpty) return const SizedBox.shrink();
    final p = pins.first;
    return Container(
      color: T.panel,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(children: [
        Icon(Icons.push_pin, size: 18, color: T.accent),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(pins.length > 1 ? 'پیام سنجاق‌شده (${fa(pins.length)})' : 'پیام سنجاق‌شده', style: TextStyle(fontSize: 13, color: T.accent, fontWeight: FontWeight.w700)), Text(previewText(p['type']?.toString(), p['text']?.toString()), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: T.muted))])),
      ]),
    );
  }

  Widget _daySep(int ts) => Center(
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 10, 0, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          decoration: BoxDecoration(color: const Color(0x52000000), borderRadius: BorderRadius.circular(14)),
          child: Text(dayLabel(ts), style: const TextStyle(color: Colors.white, fontSize: 12.5)),
        ),
      );

  Widget _service(Map<String, dynamic> m) {
    const names = {'pin': 'پیامی را سنجاق کرد', 'call_start': 'ویس‌کال را شروع کرد', 'call_end': 'ویس‌کال را پایان داد'};
    final who = userName(_i(m['uid']));
    final txt = names[m['text']] ?? m['text'].toString();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(color: const Color(0x52000000), borderRadius: BorderRadius.circular(14)),
        child: Text('$who $txt', style: const TextStyle(color: Colors.white, fontSize: 12.5)),
      ),
    );
  }

  Widget _quote(Map<String, dynamic> m, Color rc) {
    final ru = _i(m['ru']);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 2, 0, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: rc.withOpacity(.14), border: Border(right: BorderSide(color: rc, width: 3)), borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8), topRight: Radius.circular(4), bottomRight: Radius.circular(4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(ru == 0 ? 'پیام' : userName(ru), style: TextStyle(color: rc, fontSize: 12.5, fontWeight: FontWeight.w700)),
        Text(previewText(m['rty']?.toString(), m['rt']?.toString()), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
      ]),
    );
  }

  Widget _content(Map<String, dynamic> m, bool me) {
    final type = (m['type'] ?? 'text').toString();
    final text = (m['text'] ?? '').toString();
    final file = (m['file'] ?? '').toString();
    final url = Api.i.url(file);
    const ph = ['📷 عکس', '🎤 پیام صوتی', 'استیکر'];
    final cap = ph.contains(text) ? '' : text;
    Widget? media;
    switch (type) {
      case 'image':
        media = GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ImageViewPage(url))),
          child: ClipRRect(borderRadius: BorderRadius.circular(11), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 340, minHeight: 100, minWidth: 160), child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, placeholder: (_, __) => Container(width: 220, height: 160, color: const Color(0x22000000)), errorWidget: (_, __, ___) => Container(width: 220, height: 120, color: const Color(0x22000000), child: const Icon(Icons.broken_image_outlined))))),
        );
        break;
      case 'video':
        media = GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _VideoPage(url))),
          child: Container(width: 240, height: 170, decoration: BoxDecoration(color: const Color(0xFF16202A), borderRadius: BorderRadius.circular(11)), child: const Center(child: CircleAvatar(radius: 28, backgroundColor: Color(0x99000000), child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36)))),
        );
        break;
      case 'gif':
        media = (url.endsWith('.mp4') || url.endsWith('.webm'))
            ? ClipRRect(borderRadius: BorderRadius.circular(11), child: SizedBox(width: 220, height: 160, child: _InlineVideo(url)))
            : ClipRRect(borderRadius: BorderRadius.circular(11), child: CachedNetworkImage(imageUrl: url, width: 220, fit: BoxFit.cover));
        break;
      case 'sticker':
        media = CachedNetworkImage(imageUrl: url, width: 150, height: 150, fit: BoxFit.contain);
        break;
      case 'voice':
        media = _VoiceBubble(url, int.tryParse(text) ?? 0, me);
        break;
      case 'file':
        media = GestureDetector(
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 22, backgroundColor: T.accent, child: const Icon(Icons.insert_drive_file_outlined, color: Colors.white)),
            const SizedBox(width: 10),
            Flexible(child: Text(text.isEmpty ? 'فایل' : text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
        break;
      case 'poll':
        media = _pollView(m);
        break;
    }
    if (media != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        media,
        if (cap.isNotEmpty && type != 'poll' && type != 'file' && type != 'voice' && type != 'sticker')
          Padding(padding: const EdgeInsets.only(top: 4), child: _Linkified(stripFmt(cap))),
      ]);
    }
    return _Linkified(stripFmt(text));
  }

  Widget _pollView(Map<String, dynamic> m) {
    Map<String, dynamic> p;
    try {
      p = _m(jsonDecode(m['text'].toString()));
    } catch (_) {
      return const Text('نظرسنجی');
    }
    final opts = (p['opts'] as List? ?? []).map((e) => e.toString()).toList();
    final st = polls[_i(m['id'])] ?? {};
    final c = st['c'] is Map ? Map<String, dynamic>.from(st['c'] as Map) : <String, dynamic>{};
    final mine = (st['m'] as List? ?? []).map(_i).toSet();
    final nTotal = opts.asMap().keys.fold<int>(0, (a, i) => a + _i(c['$i']));
    final voted = mine.isNotEmpty;
    return SizedBox(
      width: 250,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((p['q'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        Text(p['multi'] == 1 ? 'نظرسنجی · چندگزینه‌ای' : 'نظرسنجی', style: TextStyle(fontSize: 12, color: T.muted)),
        const SizedBox(height: 8),
        for (int i = 0; i < opts.length; i++)
          GestureDetector(
            onTap: () => _vote(_i(m['id']), i),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: T.hover, borderRadius: BorderRadius.circular(10)),
              child: Stack(children: [
                Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerRight, widthFactor: voted && nTotal > 0 ? _i(c['$i']) / nTotal : 0, child: Container(color: T.accent.withOpacity(.22)))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(children: [
                    Icon(mine.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: T.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(opts[i])),
                    if (voted) Text('${fa((nTotal > 0 ? (_i(c['$i']) * 100 / nTotal).round() : 0))}٪', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          ),
        Text('${fa(_i(st['n']) > 0 ? _i(st['n']) : nTotal)} رأی', style: TextStyle(fontSize: 12, color: T.muted)),
      ]),
    );
  }

  Widget _reactions(int id, Color bubbleColor) {
    final l = reacts[id];
    if (l == null || l.isEmpty) return const SizedBox.shrink();
    final by = <String, List<int>>{};
    for (final x in l) {
      by.putIfAbsent(x[0].toString(), () => []).add(_i(x[1]));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (final e in by.entries)
            GestureDetector(
              onTap: () => _react(id, e.key),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: e.value.contains(meId) ? T.accent : T.accent.withOpacity(.17), borderRadius: BorderRadius.circular(13)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.key, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 4),
                  Text(fa(e.value.length), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: e.value.contains(meId) ? Colors.white : T.text)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _meta(Map<String, dynamic> m, bool me, {bool overlay = false}) {
    final pending = m['pending'] == true;
    final col = overlay ? Colors.white : T.text.withOpacity(.55);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_i(m['edited']) == 1) Text('ویرایش‌شده ', style: TextStyle(fontSize: 11, color: col, fontStyle: FontStyle.italic)),
        if (isC) ...[Icon(Icons.remove_red_eye_outlined, size: 12, color: col), const SizedBox(width: 3), Text(fa(_i(m['views'])), style: TextStyle(fontSize: 11, color: col)), const SizedBox(width: 6)],
        Text(fmtTime(_i(m['ts'])), style: TextStyle(fontSize: 11, color: col)),
        if (me && !isC) ...[
          const SizedBox(width: 4),
          Icon(pending ? Icons.access_time_rounded : (isP && _i(m['id']) <= readUpto ? Icons.done_all_rounded : Icons.done_rounded), size: 14, color: overlay ? Colors.white : (isP && _i(m['id']) <= readUpto ? T.tick : T.muted)),
        ],
      ]),
    );
  }

  Widget _msg(int idx) {
    final m = msgs[idx];
    final prev = idx > 0 ? msgs[idx - 1] : null;
    final next = idx < msgs.length - 1 ? msgs[idx + 1] : null;
    final ts = _i(m['ts']);
    final showDay = prev == null || dayKey(tsDate(_i(prev['ts']))) != dayKey(tsDate(ts));
    final children = <Widget>[if (showDay) _daySep(ts)];
    if (m['type'] == 'service') {
      children.add(_service(m));
      return Column(children: children);
    }
    final me = _i(m['uid']) == meId && !(isC && false);
    final uid = _i(m['uid']);
    final gs = prev == null || showDay || _i(prev['uid']) != uid || prev['type'] == 'service';
    final ge = next == null || _i(next['uid']) != uid || next['type'] == 'service' || dayKey(tsDate(_i(next['ts']))) != dayKey(tsDate(ts));
    final sticker = m['type'] == 'sticker';
    final showName = isG && !me && gs;
    final rc = colorOf(uid);
    final r = const Radius.circular(15);
    const t = Radius.circular(5);
    const b = Radius.circular(4);
    final radius = me
        ? BorderRadius.only(topLeft: r, bottomLeft: r, topRight: gs ? r : t, bottomRight: ge ? b : r)
        : BorderRadius.only(topRight: r, bottomRight: r, topLeft: gs ? r : t, bottomLeft: ge ? b : r);
    final w = MediaQuery.of(context).size.width;
    final mediaOverlay = (m['type'] == 'image' || m['type'] == 'video' || m['type'] == 'gif') && ((m['text'] ?? '').toString().isEmpty || ['📷 عکس'].contains(m['text']));
    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: w * 0.8),
      padding: sticker ? EdgeInsets.zero : const EdgeInsets.fromLTRB(9, 5, 9, 4),
      decoration: sticker ? null : BoxDecoration(color: me ? T.outBub : T.inBub, borderRadius: radius, boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 2, offset: Offset(0, 1))]),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (showName) Padding(padding: const EdgeInsets.only(bottom: 1), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(userName(uid), style: TextStyle(color: rc, fontWeight: FontWeight.w700, fontSize: 13.5)), NameBadge(users[uid], size: 14)])),
          if ((m['fwd'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('فوروارد از ${m['fwd']}', style: TextStyle(fontSize: 13, color: T.accent, fontWeight: FontWeight.w700))),
          if (_i(m['rid']) > 0) _quote(m, rc),
          _content(m, me),
          _reactions(_i(m['id']), me ? T.outBub : T.inBub),
          if (!mediaOverlay || true) Padding(padding: const EdgeInsets.only(top: 2), child: Align(alignment: Alignment.centerRight, child: _meta(m, me))),
        ]),
      ),
    );
    bubble = GestureDetector(onLongPress: () => _msgMenu(m), onDoubleTap: () => _react(_i(m['id']), '👍'), child: Opacity(opacity: m['pending'] == true ? .7 : 1, child: bubble));
    children.add(Padding(
      padding: EdgeInsets.only(top: gs ? 7 : 1, bottom: 1, left: 6, right: 6),
      child: Row(
        mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isG && !me) ...[ge ? Avatar(size: 34, uid: uid, ringGap: Colors.transparent) : const SizedBox(width: 34), const SizedBox(width: 6)],
          Flexible(child: bubble),
        ],
      ),
    ));
    return Column(children: children);
  }

  Widget _composer() {
    final bottom = MediaQuery.of(context).padding.bottom;
    if (muted) return _lockBar('شما سکوت شده‌اید و نمی‌توانید پیام بفرستید.', bottom);
    if (lock && (isC || isG)) return _lockBar(isC ? 'فقط مدیران می‌توانند در کانال پست بگذارند.' : 'فقط مدیران می‌توانند پیام بفرستند.', bottom);
    final has = _input.text.trim().isNotEmpty;
    final bar = replyTo != null || editId != null;
    return Container(
      color: T.panel,
      padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (bar)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(children: [
              Icon(editId != null ? Icons.edit_outlined : Icons.reply_rounded, color: T.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(editId != null ? 'ویرایش پیام' : userName(_i(replyTo!['uid'])), style: TextStyle(color: T.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                if (editId == null) Text(previewText(replyTo!['type']?.toString(), replyTo!['text']?.toString()), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: T.muted, fontSize: 13)),
              ])),
              IconButton(icon: Icon(Icons.close_rounded, color: T.muted, size: 20), onPressed: () => setState(() { replyTo = null; if (editId != null) _input.clear(); editId = null; })),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          IconButton(icon: Icon(Icons.attach_file_rounded, color: T.muted), onPressed: _attachMenu),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: T.hover, borderRadius: BorderRadius.circular(22)),
              child: TextField(
                controller: _input,
                focusNode: _focus,
                minLines: 1,
                maxLines: 6,
                maxLength: 4000,
                onChanged: _onChanged,
                textDirection: _dirOf(_input.text),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(border: InputBorder.none, counterText: '', hintText: slow > 0 && isG && !meAdmin ? 'حالت آهسته: هر ${fa(slow)} ثانیه' : 'پیام', hintStyle: TextStyle(color: T.muted)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: has ? _sendText : null,
            child: AnimatedOpacity(
              opacity: has ? 1 : .45,
              duration: const Duration(milliseconds: 120),
              child: Container(width: 46, height: 46, decoration: BoxDecoration(color: T.accent, shape: BoxShape.circle), child: Icon(editId != null ? Icons.check_rounded : Icons.send_rounded, color: Colors.white, size: 22)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _lockBar(String t, double bottom) => Container(
        width: double.infinity,
        color: T.panel,
        padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: T.muted, fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: T.dark ? Brightness.light : Brightness.dark, statusBarBrightness: T.dark ? Brightness.dark : Brightness.light),
      child: Scaffold(
        backgroundColor: T.bg,
        resizeToAvoidBottomInset: true,
        body: Column(children: [
          _topBar(),
          _pinBar(),
          Expanded(
            child: Container(
              decoration: T.chatDecoration,
              child: !inited
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : (msgs.isEmpty
                      ? Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: const Color(0x52000000), borderRadius: BorderRadius.circular(14)), child: const Text('هنوز پیامی نیست', style: TextStyle(color: Colors.white))))
                      : Directionality(
                          textDirection: TextDirection.ltr,
                          child: ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
                            itemCount: msgs.length + (more ? 1 : 0),
                            itemBuilder: (c, i) {
                              if (i >= msgs.length) return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))));
                              return _msg(msgs.length - 1 - i);
                            },
                          ),
                        )),
            ),
          ),
          _composer(),
        ]),
      ),
    );
  }
}

/* ===================== ویجت‌های کمکی ===================== */

/// متن با لینک و @منشن قابل لمس
class _Linkified extends StatefulWidget {
  final String text;
  const _Linkified(this.text);
  @override
  State<_Linkified> createState() => _LinkifiedState();
}

class _LinkifiedState extends State<_Linkified> {
  final List<TapGestureRecognizer> _rec = [];

  @override
  void dispose() {
    for (final r in _rec) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _rec) {
      r.dispose();
    }
    _rec.clear();
    final spans = <InlineSpan>[];
    var last = 0;
    final re = RegExp(r'(https?://[^\s<>"]+)|(@[\w\u0600-\u06FF]{2,32})');
    for (final mt in re.allMatches(widget.text)) {
      if (mt.start > last) spans.add(TextSpan(text: widget.text.substring(last, mt.start)));
      final s = mt[0]!;
      if (s.startsWith('http')) {
        final r = TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(s), mode: LaunchMode.externalApplication);
        _rec.add(r);
        spans.add(TextSpan(text: s, style: TextStyle(color: T.accent), recognizer: r));
      } else {
        spans.add(TextSpan(text: s, style: TextStyle(color: T.accent, fontWeight: FontWeight.w700)));
      }
      last = mt.end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));
    return Text.rich(TextSpan(children: spans), textDirection: _dirOf(widget.text), style: const TextStyle(fontSize: 15, height: 1.55));
  }
}

class _ImageViewPage extends StatelessWidget {
  final String url;
  const _ImageViewPage(this.url);
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(child: InteractiveViewer(minScale: 1, maxScale: 5, child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain, placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white))))),
          Positioned(top: MediaQuery.of(context).padding.top + 6, right: 8, child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop())),
          Positioned(top: MediaQuery.of(context).padding.top + 6, left: 8, child: IconButton(icon: const Icon(Icons.download_rounded, color: Colors.white), onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication))),
        ]),
      );
}

/// پخش‌کننده‌ی تمام‌صفحه‌ی ویدیو (جایگزین پخش‌کننده‌ی مشکل‌دار وب)
class _VideoPage extends StatefulWidget {
  final String url;
  const _VideoPage(this.url);
  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController c;
  bool ready = false, failed = false, controls = true;

  @override
  void initState() {
    super.initState();
    c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: false));
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() => ready = true);
      c.play();
    }).catchError((_) {
      if (mounted) setState(() => failed = true);
    });
    c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => '${d.inMinutes}:${two(d.inSeconds % 60)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => controls = !controls),
            child: Center(
              child: failed
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('پخش ویدیو ممکن نشد.', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication), child: const Text('باز کردن در مرورگر')),
                    ])
                  : ready
                      ? AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))
                      : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
        if (ready && c.value.isBuffering) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (controls) ...[
          Positioned(top: MediaQuery.of(context).padding.top + 6, right: 8, child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop())),
          if (ready)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [
                  IconButton(icon: Icon(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 34), onPressed: () => c.value.isPlaying ? c.pause() : c.play()),
                  Text(_fmt(c.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white30, backgroundColor: Colors.white12)))),
                  Text(_fmt(c.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}

class _InlineVideo extends StatefulWidget {
  final String url;
  const _InlineVideo(this.url);
  @override
  State<_InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<_InlineVideo> {
  late final VideoPlayerController c;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    c.initialize().then((_) {
      if (!mounted) return;
      c.setLooping(true);
      c.setVolume(0);
      c.play();
      setState(() => ready = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ready ? FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))) : Container(color: const Color(0x22000000));
}

class _VoiceBubble extends StatefulWidget {
  final String url;
  final int secs;
  final bool me;
  const _VoiceBubble(this.url, this.secs, this.me);
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  VideoPlayerController? c;
  bool loading = false;

  Future<void> _toggle() async {
    if (c == null) {
      setState(() => loading = true);
      final n = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      try {
        await n.initialize();
      } catch (_) {
        n.dispose();
        if (mounted) setState(() => loading = false);
        return;
      }
      n.addListener(() {
        if (mounted) setState(() {});
        if (n.value.position >= n.value.duration && n.value.duration > Duration.zero) {
          n.seekTo(Duration.zero);
          n.pause();
        }
      });
      c = n;
      loading = false;
      n.play();
      if (mounted) setState(() {});
      return;
    }
    c!.value.isPlaying ? c!.pause() : c!.play();
  }

  @override
  void dispose() {
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = c?.value.isPlaying ?? false;
    final dur = c != null && c!.value.isInitialized ? c!.value.duration.inSeconds : widget.secs;
    final pos = c != null && c!.value.isInitialized ? c!.value.position.inSeconds : 0;
    final prog = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 210,
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: CircleAvatar(radius: 21, backgroundColor: T.accent, child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: prog.toDouble(), minHeight: 4, backgroundColor: T.accent.withOpacity(.25), valueColor: AlwaysStoppedAnimation(T.accent))),
            const SizedBox(height: 4),
            Text('${dur ~/ 60}:${two(dur % 60)}', style: TextStyle(fontSize: 12, color: T.muted)),
          ]),
        ),
      ]),
    );
  }
}
