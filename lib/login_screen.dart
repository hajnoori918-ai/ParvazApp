import 'package:flutter/material.dart';

import 'api_service.dart';
import 'common.dart';
import 'home_screen.dart';

/// صفحه‌ی ورود / ثبت‌نام — کپی طراحی #login سایت (کارت سفید روی گرادیان سبز-آبی).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  final _p2 = TextEditingController();
  final _t = TextEditingController();
  bool register = false, show = false, busy = false, needTotp = false;
  String err = '';

  static const _ink = Color(0xFF14202B);
  static const _fieldBg = Color(0xFFF1F4F7);
  static const _fieldBorder = Color(0xFFE1E6EC);
  static const _btnBg = Color(0xFFE4E9EF);

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    _p2.dispose();
    _t.dispose();
    super.dispose();
  }

  void _setMode(bool reg) {
    setState(() {
      register = reg;
      err = '';
      needTotp = false;
    });
  }

  Future<void> _submit() async {
    final u = _u.text.trim(), p = _p.text;
    String? e;
    if (u.length < 2 || u.length > 30) {
      e = 'نام باید بین ۲ تا ۳۰ حرف باشد.';
    } else if (p.isEmpty) {
      e = 'رمز عبور را وارد کنید.';
    } else if (register && p.length < 6) {
      e = 'رمز باید حداقل ۶ کاراکتر باشد.';
    } else if (register && p != _p2.text) {
      e = 'رمز و تکرار آن یکسان نیست.';
    }
    if (e != null) {
      setState(() => err = e!);
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    final j = await Api.i.login(u, p, register: register, password2: register ? _p2.text : null, totp: needTotp ? _t.text.trim() : null);
    if (!mounted) return;
    if (j['status'] == 'ok') {
      applyCfg(Api.i.cfg);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }
    setState(() {
      busy = false;
      if (j['status'] == 'totp') needTotp = true;
      err = (j['message'] ?? 'خطا').toString();
    });
  }

  Future<void> _editServer() async {
    final c = TextEditingController(text: Api.i.base);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.ltr,
        child: AlertDialog(
          title: const Text('آدرس سرور'),
          content: TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://example.com/')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await Api.i.setBase(c.text);
      final j = await Api.i.boot();
      if (mounted) toast(context, j['status'] == 'ok' ? 'آدرس سرور ذخیره شد' : (j['message'] ?? 'خطا').toString());
    }
  }

  Widget _circleBtn(double s, IconData ic, double isz, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(width: s, height: s, decoration: const BoxDecoration(color: _btnBg, shape: BoxShape.circle), child: Icon(ic, size: isz, color: const Color(0xFF4D5B69))),
      );

  Widget _field(TextEditingController c, String hint, {bool pass = false, TextInputType? kb, int? maxLen}) {
    Widget? suffix;
    if (pass) {
      suffix = Padding(
        padding: const EdgeInsetsDirectional.only(end: 7),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (c.text.isNotEmpty) ...[_circleBtn(34, Icons.close_rounded, 15, () => setState(c.clear)), const SizedBox(width: 6)],
          _circleBtn(40, show ? Icons.visibility_off_outlined : Icons.visibility_outlined, 18, () => setState(() => show = !show)),
        ]),
      );
    } else if (c.text.isNotEmpty) {
      suffix = Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: _circleBtn(34, Icons.close_rounded, 15, () => setState(c.clear)));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: pass && !show,
        keyboardType: kb,
        maxLength: maxLen,
        autocorrect: false,
        enableSuggestions: !pass,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
        style: const TextStyle(fontSize: 16.5, color: _ink),
        cursorColor: const Color(0xFF2E86D6),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8A97A5)),
          filled: true,
          fillColor: _fieldBg,
          isDense: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(minHeight: 40, minWidth: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _fieldBorder, width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _fieldBorder, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2E86D6), width: 1.5)),
        ),
      ),
    );
  }

  Widget _tab(String label, bool on, VoidCallback f) => Expanded(
        child: GestureDetector(
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? const Color(0xFF3390EC) : Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: on ? const Color(0xFF3390EC) : const Color(0xFFD3DBE4), width: 2),
            ),
            child: Text(label, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: on ? Colors.white : const Color(0xFF3A4856))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A9D8F), Color(0xFF264653)])),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 10))]),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: _ink),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Center(
                        child: GestureDetector(
                          onLongPress: _editServer,
                          child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/icon.png', width: 84, height: 84)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Center(child: Text('Parvaz', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: .5, color: _ink))),
                      const SizedBox(height: 8),
                      Row(children: [_tab('ورود', !register, () => _setMode(false)), const SizedBox(width: 10), _tab('ثبت‌نام', register, () => _setMode(true))]),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 16),
                        child: Text(
                          register ? 'یک نام کاربری و رمز عبور (حداقل ۶ کاراکتر) انتخاب کنید.' : 'با نام کاربری و رمز عبور خود وارد شوید.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.9, color: Color(0xFF4D5B69)),
                        ),
                      ),
                      _field(_u, 'نام کاربری', maxLen: 30),
                      _field(_p, 'رمز عبور', pass: true),
                      if (register) _field(_p2, 'تکرار رمز عبور', pass: true),
                      if (needTotp) _field(_t, 'کد ۶ رقمی تأیید دو مرحله‌ای', kb: TextInputType.number, maxLen: 6),
                      SizedBox(
                        height: 28,
                        child: Align(alignment: Alignment.center, child: Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE5484D), fontSize: 14))),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: busy ? null : _submit,
                        child: Container(
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF34C759), Color(0xFF1F9D4C)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [BoxShadow(color: Color(0x6634C759), blurRadius: 22, offset: Offset(0, 8))],
                          ),
                          child: busy
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                              : Text(register ? 'ساخت حساب' : 'ورود به Parvaz', style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        register ? 'از هر شبکه حداکثر ۵ حساب می‌توان ساخت؛ نام را با دقت بنویسید.' : 'حساب شما روی این دستگاه ذخیره می‌ماند.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, height: 1.8, color: Color(0xFF6B7886)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
