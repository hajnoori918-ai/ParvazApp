import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// اتصال به api.php سایت Parvaz.
/// - نشست (PHPSESSID و کوکی rm) ذخیره و با هر درخواست ارسال می‌شود.
/// - هدر X-Session-ID و پارامتر app_mode=1 هم با هر درخواست فرستاده می‌شود.
/// - توکن csrf از عملیات app_boot گرفته می‌شود (نیاز به فایل‌های backend همین پروژه).
class Api {
  Api._();
  static final Api i = Api._();

  /// آدرس پیش‌فرض سرور (با / در انتها). از صفحه‌ی ورود هم (نگه‌داشتن لوگو) قابل تغییر است.
  static const String defaultBase = 'https://noorir.isfpardaz.ir/';

  String base = defaultBase;
  String csrf = '';
  String sessionId = '';
  Map<String, dynamic> cfg = {};
  void Function()? onAuthLost;

  final Map<String, String> _cookies = {};
  final http.Client _client = http.Client();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    base = _norm(_prefs!.getString('base') ?? defaultBase);
    sessionId = _prefs!.getString('sid') ?? '';
    final raw = _prefs!.getString('cookies');
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map).forEach((k, v) => _cookies[k.toString()] = v.toString());
      } catch (_) {}
    }
  }

  static String _norm(String s) {
    s = s.trim();
    if (s.isEmpty) return defaultBase;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
    if (!s.endsWith('/')) s = '$s/';
    return s;
  }

  Future<void> setBase(String s) async {
    base = _norm(s);
    await _prefs?.setString('base', base);
  }

  Future<void> _save() async {
    await _prefs?.setString('cookies', jsonEncode(_cookies));
    await _prefs?.setString('sid', sessionId);
  }

  Future<void> clearSession() async {
    _cookies.clear();
    sessionId = '';
    csrf = '';
    await _save();
  }

  String get endpoint => '${base}api.php';

  /// تبدیل مسیر نسبی (مثل uploads/x.jpg) به آدرس کامل.
  String url(String? p) {
    if (p == null || p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (p.startsWith('/')) return base.substring(0, base.length - 1) + p;
    return base + p;
  }

  Map<String, String> _headers() {
    final h = <String, String>{'User-Agent': 'ParvazApp/1.0', 'X-Requested-With': 'ParvazApp'};
    if (_cookies.isNotEmpty) h['Cookie'] = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    if (sessionId.isNotEmpty) h['X-Session-ID'] = sessionId;
    return h;
  }

  void _absorb(Map<String, String> h) {
    final sc = h['set-cookie'];
    if (sc != null && sc.isNotEmpty) {
      for (final part in sc.split(RegExp(r',(?=\s*[A-Za-z0-9_\-]+=)'))) {
        final first = part.split(';').first.trim();
        final eq = first.indexOf('=');
        if (eq <= 0) continue;
        final k = first.substring(0, eq);
        final v = first.substring(eq + 1);
        if (v.isEmpty || v == 'deleted') {
          _cookies.remove(k);
        } else {
          _cookies[k] = v;
        }
      }
    }
    final sid = h['x-session-id'];
    if (sid != null && sid.isNotEmpty) sessionId = sid;
  }

  /// فراخوانی یک action از api.php. همیشه یک Map برمی‌گرداند (status = ok | error | totp).
  Future<Map<String, dynamic>> call(String action,
      [Map<String, dynamic>? fields, List<http.MultipartFile>? files, bool retried = false]) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(endpoint));
      req.headers.addAll(_headers());
      req.fields['action'] = action;
      req.fields['csrf'] = csrf;
      req.fields['app_mode'] = '1';
      fields?.forEach((k, v) {
        if (v == null) return;
        if (v is String) {
          req.fields[k] = v;
        } else if (v is num) {
          req.fields[k] = v.toString();
        } else if (v is bool) {
          req.fields[k] = v ? '1' : '';
        } else {
          req.fields[k] = jsonEncode(v);
        }
      });
      if (files != null) req.files.addAll(files);
      final streamed = await _client.send(req).timeout(Duration(seconds: files == null ? 30 : 240));
      final res = await http.Response.fromStream(streamed);
      _absorb(res.headers);
      await _save();
      Map<String, dynamic> j;
      try {
        j = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
      } catch (_) {
        return {'status': 'error', 'message': 'پاسخ نامعتبر از سرور (آدرس سرور یا فایل‌های backend را بررسی کنید).', 'code': 'bad'};
      }
      if (j['status'] == 'error' && j['code'] == 'csrf' && !retried && files == null) {
        await boot();
        return call(action, fields, null, true);
      }
      if (j['status'] == 'error' && j['code'] == 'auth') onAuthLost?.call();
      return j;
    } on TimeoutException {
      return {'status': 'error', 'message': 'زمان اتصال به سرور تمام شد.', 'code': 'net'};
    } catch (_) {
      return {'status': 'error', 'message': 'اتصال به سرور برقرار نیست.', 'code': 'net'};
    }
  }

  /// دریافت csrf + تنظیمات اولیه + کاربر فعلی (اگر وارد شده باشد).
  Future<Map<String, dynamic>> boot() async {
    final j = await call('app_boot', null, null, true);
    if (j['status'] == 'ok') {
      csrf = (j['csrf'] ?? '').toString();
      cfg = j;
    }
    return j;
  }

  Future<http.MultipartFile> file(String field, String path, {String? name}) =>
      http.MultipartFile.fromPath(field, path, filename: name);

  Future<Map<String, dynamic>> login(String username, String password,
      {bool register = false, String? password2, String? totp}) async {
    final f = <String, dynamic>{
      'username': username,
      'password': password,
      'mode': register ? 'register' : 'login',
    };
    if (register && password2 != null) f['password2'] = password2;
    if (totp != null && totp.isNotEmpty) f['totp'] = totp;
    final j = await call('login', f);
    if (j['status'] == 'ok') await boot();
    return j;
  }

  Future<void> logout() async {
    await call('logout');
    await clearSession();
    await boot();
  }
}
