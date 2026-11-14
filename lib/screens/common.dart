import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';

/* ===================== تم‌ها (کپی متغیرهای CSS سایت) ===================== */

class PTheme {
  final String key;
  final bool dark;
  final Color accent, bg, panel, text, muted, line, inBub, outBub, hover, tick;
  final Color chatColor;
  final Gradient? chatGradient;
  const PTheme({
    required this.key,
    required this.accent,
    required this.bg,
    required this.panel,
    required this.text,
    required this.muted,
    required this.line,
    required this.inBub,
    required this.outBub,
    required this.tick,
    required this.chatColor,
    this.chatGradient,
    this.dark = false,
    this.hover = const Color(0x0F000000),
  });

  Color get hbar => Color.lerp(accent, const Color(0xFF12202E), 0.2)!;

  BoxDecoration get chatDecoration => BoxDecoration(color: chatColor, gradient: chatGradient);
}

LinearGradient _lin(List<Color> c, List<double> s) =>
    LinearGradient(begin: const Alignment(-0.34, -1), end: const Alignment(0.34, 1), colors: c, stops: s);

final Map<String, PTheme> themes = {
  'tg': PTheme(
    key: 'tg', accent: const Color(0xFF3390EC), bg: Colors.white, panel: Colors.white, text: const Color(0xFF0F1419),
    muted: const Color(0xFF707579), line: const Color(0xFFE7E7E7), inBub: Colors.white, outBub: const Color(0xFFEEFFDE),
    tick: const Color(0xFF4FAE4E), chatColor: const Color(0xFFB6D8E6),
    chatGradient: _lin(const [Color(0xFF8FB4DE), Color(0xFFB6D8E6), Color(0xFFD6E7C5)], const [0, .48, 1]),
  ),
  'dark': const PTheme(
    key: 'dark', dark: true, accent: Color(0xFF6AB3F3), bg: Color(0xFF0E1621), panel: Color(0xFF17212B), text: Color(0xFFF5F5F5),
    muted: Color(0xFF8A9AAB), line: Color(0xFF0B1119), inBub: Color(0xFF182533), outBub: Color(0xFF2B5278),
    tick: Color(0xFF7EC8F5), chatColor: Color(0xFF0E1621), hover: Color(0x12FFFFFF),
  ),
  'purple': const PTheme(
    key: 'purple', accent: Color(0xFF8E44AD), bg: Color(0xFFF6EDF9), panel: Colors.white, text: Color(0xFF22102C),
    muted: Color(0xFF80708A), line: Color(0xFFE9D9F0), inBub: Colors.white, outBub: Color(0xFFECD2F8),
    tick: Color(0xFF8E44AD), chatColor: Color(0xFFD8B9E8),
  ),
  'blue': const PTheme(
    key: 'blue', accent: Color(0xFF1565C0), bg: Color(0xFFEAF3FC), panel: Colors.white, text: Color(0xFF0C1D30),
    muted: Color(0xFF5D7287), line: Color(0xFFD5E5F5), inBub: Colors.white, outBub: Color(0xFFC8E0FA),
    tick: Color(0xFF1565C0), chatColor: Color(0xFFA8CDF0),
  ),
  'midnight': PTheme(
    key: 'midnight', dark: true, accent: const Color(0xFF9A8CFF), bg: Colors.black, panel: const Color(0xFF0C0C12),
    text: const Color(0xFFF2F2F7), muted: const Color(0xFF8B8B9A), line: const Color(0xFF16161E),
    inBub: const Color(0xFF16161F), outBub: const Color(0xFF3B2F7A), tick: const Color(0xFFB9AFFF),
    chatColor: Colors.black, hover: const Color(0x12FFFFFF),
    chatGradient: const RadialGradient(center: Alignment(-0.6, -1), radius: 1.1, colors: [Color(0xFF1A1033), Colors.black], stops: [0, .6]),
  ),
  'ocean': PTheme(
    key: 'ocean', accent: const Color(0xFF0D8ABF), bg: const Color(0xFFE6F6F4), panel: Colors.white, text: const Color(0xFF0B2A33),
    muted: const Color(0xFF5D7F87), line: const Color(0xFFCFE8E6), inBub: Colors.white, outBub: const Color(0xFFC9F1E6),
    tick: const Color(0xFF0D8ABF), chatColor: const Color(0xFF2A9FB8),
    chatGradient: _lin(const [Color(0xFF43CEA2), Color(0xFF2A9FB8), Color(0xFF185A9D)], const [0, .55, 1]),
  ),
  'sunset': PTheme(
    key: 'sunset', accent: const Color(0xFFF0553B), bg: const Color(0xFFFFF3EE), panel: Colors.white, text: const Color(0xFF2D1410),
    muted: const Color(0xFF8A6A63), line: const Color(0xFFF6DDD4), inBub: Colors.white, outBub: const Color(0xFFFFE1CF),
    tick: const Color(0xFFF0553B), chatColor: const Color(0xFFFF6F61),
    chatGradient: _lin(const [Color(0xFFFFB36B), Color(0xFFFF6F61), Color(0xFFC2417A)], const [0, .55, 1]),
  ),
  'forest': PTheme(
    key: 'forest', accent: const Color(0xFF2E8B3D), bg: const Color(0xFFEEF7EA), panel: Colors.white, text: const Color(0xFF12280F),
    muted: const Color(0xFF5F7A5A), line: const Color(0xFFD9EAD3), inBub: Colors.white, outBub: const Color(0xFFD8F2C4),
    tick: const Color(0xFF2E8B3D), chatColor: const Color(0xFF56AB2F),
    chatGradient: _lin(const [Color(0xFFA8E063), Color(0xFF56AB2F), Color(0xFF1E6B3A)], const [0, .55, 1]),
  ),
  'rose': PTheme(
    key: 'rose', accent: const Color(0xFFD81B60), bg: const Color(0xFFFFF0F5), panel: Colors.white, text: const Color(0xFF2E0F1B),
    muted: const Color(0xFF8A5F70), line: const Color(0xFFF6D8E3), inBub: Colors.white, outBub: const Color(0xFFFFD9E6),
    tick: const Color(0xFFD81B60), chatColor: const Color(0xFFE7699A),
    chatGradient: _lin(const [Color(0xFFF6A5C0), Color(0xFFE7699A), Color(0xFF9C2A6B)], const [0, .55, 1]),
  ),
  'gold': PTheme(
    key: 'gold', accent: const Color(0xFFB8860B), bg: const Color(0xFFFFF8E1), panel: const Color(0xFFFFFDF5), text: const Color(0xFF2B2105),
    muted: const Color(0xFF8A7A4A), line: const Color(0xFFF0E2B6), inBub: Colors.white, outBub: const Color(0xFFFFE9A8),
    tick: const Color(0xFFB8860B), chatColor: const Color(0xFFE8B94A),
    chatGradient: _lin(const [Color(0xFFFFE27A), Color(0xFFE8B94A), Color(0xFF8A5A00)], const [0, .5, 1]),
  ),
  'neon': PTheme(
    key: 'neon', dark: true, accent: const Color(0xFF00E5FF), bg: const Color(0xFF06070F), panel: const Color(0xFF0C0E1D),
    text: const Color(0xFFEAF6FF), muted: const Color(0xFF7F8DB3), line: const Color(0xFF151A33), inBub: const Color(0xFF141830),
    outBub: const Color(0xFF3A1D6E), tick: const Color(0xFF00E5FF), chatColor: const Color(0xFF06070F), hover: const Color(0x12FFFFFF),
    chatGradient: const RadialGradient(center: Alignment(-0.7, -0.8), radius: 1.1, colors: [Color(0xFF2A0A4D), Color(0xFF06070F)], stops: [0, .62]),
  ),
};

final ValueNotifier<PTheme> themeN = ValueNotifier<PTheme>(themes['tg']!);
PTheme get T => themeN.value;

/// اطلاعات کاربر فعلی (از app_boot)
Map<String, dynamic> ME = {};
int get meId => (ME['id'] as num?)?.toInt() ?? 0;
bool get meAdmin => ME['admin'] == true;
bool get mePremium => ME['premium'] == true;

void applyCfg(Map<String, dynamic> j) {
  final m = j['me'];
  ME = m is Map ? Map<String, dynamic>.from(m) : {};
  var k = (j['theme'] ?? 'tg').toString();
  if (k == 'light') k = 'tg';
  themeN.value = themes[k] ?? themes['tg']!;
  if (ME.isNotEmpty) {
    users[meId] = {...(users[meId] ?? {}), 'n': ME['name'], 'p': ME['pic'] ?? '', 't': ME['tick'] ?? 0, 'pr': mePremium ? 1 : 0, 'b': ME['badge'] ?? '', 'ago': 0, 'at': DateTime.now().millisecondsSinceEpoch};
  }
}

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/* ===================== کاربران ===================== */

final Map<int, Map<String, dynamic>> users = {};

void mergeUsers(dynamic m) {
  if (m is! Map) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  m.forEach((k, v) {
    final id = int.tryParse(k.toString());
    if (id == null || v is! Map) return;
    final cur = users[id] ?? <String, dynamic>{};
    cur.addAll(Map<String, dynamic>.from(v));
    cur['at'] = now;
    users[id] = cur;
  });
}

void mergeUserList(dynamic l) {
  if (l is! List) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  for (final v in l) {
    if (v is! Map) continue;
    final id = (v['id'] as num?)?.toInt();
    if (id == null) continue;
    final cur = users[id] ?? <String, dynamic>{};
    cur.addAll(Map<String, dynamic>.from(v));
    cur['at'] = now;
    users[id] = cur;
  }
}

String userName(int id) => (users[id]?['n'] ?? 'کاربر').toString();

double agoNow(Map<String, dynamic>? u) {
  if (u == null || u['ago'] == null) return 1e9;
  final at = (u['at'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
  return (u['ago'] as num).toDouble() + (DateTime.now().millisecondsSinceEpoch - at) / 1000;
}

bool isOnline(Map<String, dynamic>? u) => agoNow(u) < 35;

String presence(Map<String, dynamic>? u) {
  if (u != null && (u['bt'] ?? 0) == 1) return 'ربات رسمی';
  final a = agoNow(u);
  if (a < 35) return 'آنلاین';
  if (a >= 888000 && a < 999000) return 'اخیراً آنلاین بود';
  if (a >= 999999) return 'مدت‌ها پیش آنلاین بوده';
  final m = (a / 60).floor();
  if (m < 1) return 'لحظاتی پیش آنلاین بود';
  if (m < 60) return 'آخرین بازدید ${fa(m)} دقیقه پیش';
  final h = m ~/ 60;
  if (h < 24) return 'آخرین بازدید ${fa(h)} ساعت پیش';
  final d = h ~/ 24;
  return d < 30 ? 'آخرین بازدید ${fa(d)} روز پیش' : 'آخرین بازدید مدت‌ها پیش';
}

/* ===================== ابزارهای متن و زمان ===================== */

const _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
String fa(num n) => n.toString().replaceAllMapped(RegExp(r'[0-9]'), (m) => _faDigits[int.parse(m[0]!)]);

String initial(String? s) {
  final t = (s ?? '').trim();
  if (t.isEmpty) return '?';
  return String.fromCharCode(t.runes.first).toUpperCase();
}

const _colors = [Color(0xFFE17076), Color(0xFFE8924F), Color(0xFFA695E7), Color(0xFF5FAE4B), Color(0xFF3FA9B0), Color(0xFF4A9EDE), Color(0xFFD9679B)];
Color colorOf(int id) => _colors[id.abs() % _colors.length];

String two(int n) => n.toString().padLeft(2, '0');
DateTime tsDate(int ts) => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
String fmtTime(int ts) {
  final d = tsDate(ts);
  return '${two(d.hour)}:${two(d.minute)}';
}

String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

List<int> toJalali(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) + ((gy2 + 399) ~/ 400) + gd + gdm[gm - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  int jm, jd;
  if (days < 186) {
    jm = 1 + days ~/ 31;
    jd = 1 + days % 31;
  } else {
    jm = 7 + (days - 186) ~/ 30;
    jd = 1 + (days - 186) % 30;
  }
  return [jy, jm, jd];
}

const _jMonths = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
const _weekdays = {6: 'شنبه', 7: 'یکشنبه', 1: 'دوشنبه', 2: 'سه‌شنبه', 3: 'چهارشنبه', 4: 'پنجشنبه', 5: 'جمعه'};

String jalaliDay(DateTime d, {bool year = false}) {
  final j = toJalali(d.year, d.month, d.day);
  return '${fa(j[2])} ${_jMonths[j[1] - 1]}${year ? ' ${fa(j[0])}' : ''}';
}

String listTime(int ts) {
  final d = tsDate(ts), n = DateTime.now();
  if (dayKey(d) == dayKey(n)) return fmtTime(ts);
  if (n.difference(d).inHours / 24 < 6) return _weekdays[d.weekday] ?? '';
  return jalaliDay(d);
}

String dayLabel(int ts) {
  final d = tsDate(ts), n = DateTime.now();
  if (dayKey(d) == dayKey(n)) return 'امروز';
  if (dayKey(d) == dayKey(n.subtract(const Duration(days: 1)))) return 'دیروز';
  return jalaliDay(d, year: d.year != n.year);
}

String stripFmt(String t) => t.replaceAll(RegExp(r':pe\d{1,2}:'), '✨');

String previewText(String? type, String? text) {
  var t = text ?? '';
  if (type != 'poll') t = stripFmt(t);
  const ph = ['📷 عکس', '🎤 پیام صوتی', 'استیکر'];
  switch (type) {
    case 'image':
      return '📷 ${t.isEmpty || ph.contains(t) ? 'عکس' : t}';
    case 'voice':
      return '🎤 پیام صوتی';
    case 'sticker':
      return '🖼 استیکر';
    case 'poll':
      try {
        final q = RegExp(r'"q"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(t)?.group(1);
        return '📊 ${q ?? 'نظرسنجی'}';
      } catch (_) {
        return '📊 نظرسنجی';
      }
    case 'gif':
      return '🎞 گیف${t.isNotEmpty && !ph.contains(t) ? ' $t' : ''}';
    case 'video':
      return '🎬 ویدیو${t.isNotEmpty ? ' $t' : ''}';
    case 'file':
      return '📎 $t';
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t.length > 140 ? t.substring(0, 140) : t;
}

/* ===================== ویجت‌های مشترک ===================== */

void toast(BuildContext c, String m) {
  final sm = ScaffoldMessenger.maybeOf(c);
  if (sm == null) return;
  sm.hideCurrentSnackBar();
  sm.showSnackBar(SnackBar(
    content: Text(m, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
    backgroundColor: const Color(0xE6222B36),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(40, 0, 40, 90),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    duration: const Duration(milliseconds: 2200),
  ));
}

Future<bool> askConfirm(BuildContext c, String title, String msg, String ok, {bool danger = false}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: T.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: TextStyle(color: T.text, fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(msg, style: TextStyle(color: T.muted, height: 1.7)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: TextStyle(color: T.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok, style: TextStyle(color: danger ? const Color(0xFFE53935) : T.accent, fontWeight: FontWeight.w700))),
        ],
      ),
    ),
  );
  return r == true;
}

class NameBadge extends StatelessWidget {
  final Map<String, dynamic>? u;
  final double size;
  const NameBadge(this.u, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) {
    if (u == null) return const SizedBox.shrink();
    if ((u!['pr'] ?? 0) == 1 && (u!['b'] ?? '').toString().isNotEmpty) {
      return Padding(padding: const EdgeInsetsDirectional.only(start: 3), child: Icon(Icons.star_rounded, size: size + 2, color: const Color(0xFFA76BFF)));
    }
    if ((u!['t'] ?? 0) == 1) {
      return Padding(padding: const EdgeInsetsDirectional.only(start: 3), child: Icon(Icons.verified_rounded, size: size, color: const Color(0xFF1D9BF0)));
    }
    return const SizedBox.shrink();
  }
}

class VerifiedTick extends StatelessWidget {
  final double size;
  const VerifiedTick({super.key, this.size = 16});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsetsDirectional.only(start: 3), child: Icon(Icons.verified_rounded, size: size, color: const Color(0xFF1D9BF0)));
}

class Avatar extends StatelessWidget {
  final double size;
  final int? uid;
  final String? img;
  final String? label;
  final Color? color;
  final Gradient? gradient;
  final IconData? icon;
  final int ring;
  final bool online;
  final Color? ringGap;

  const Avatar({
    super.key,
    this.size = 56,
    this.uid,
    this.img,
    this.label,
    this.color,
    this.gradient,
    this.icon,
    this.ring = 0,
    this.online = false,
    this.ringGap,
  });

  Widget _inner(double s) {
    String? url;
    var letter = '?';
    var bg = color ?? T.accent;
    if (uid != null) {
      final u = users[uid!] ?? {};
      final p = (u['p'] ?? '').toString();
      url = p.isNotEmpty ? Api.i.url('uploads/$p') : null;
      letter = initial((u['n'] ?? '?').toString());
      bg = colorOf(uid!);
    } else {
      url = (img ?? '').isNotEmpty ? Api.i.url(img) : null;
      letter = initial(label);
    }
    Widget fallback() => Container(
          width: s,
          height: s,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: gradient == null ? bg : null, gradient: gradient),
          child: icon != null
              ? Icon(icon, color: Colors.white, size: s * 0.46)
              : Text(letter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: s * 0.4)),
        );
    return ClipOval(
      child: SizedBox(
        width: s,
        height: s,
        child: (url != null && icon == null)
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 120), placeholder: (_, __) => Container(color: bg), errorWidget: (_, __, ___) => fallback())
            : fallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = ringGap ?? T.bg;
    Widget core;
    if (ring > 0) {
      core = Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ring == 1 ? const Color(0xFFB4BCC6) : null,
          gradient: ring == 2 ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3390EC), Color(0xFF35C1F1)]) : null,
        ),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gap, width: 2.5)),
          child: _inner(size - 5 - 5),
        ),
      );
    } else {
      core = _inner(size);
    }
    if (!online) return SizedBox(width: size, height: size, child: core);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        core,
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF35C759), shape: BoxShape.circle, border: Border.all(color: gap, width: 2.5))),
        ),
      ]),
    );
  }
}
