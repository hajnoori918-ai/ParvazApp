import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _pass2Controller = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true;
  String _err = '';

  Future<void> _doLogin() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;
    if (!_isLoginMode && _passController.text != _pass2Controller.text) {
      setState(() => _err = 'رمز و تکرار آن یکسان نیست.');
      return;
    }
    setState(() { _isLoading = true; _err = ''; });

    try {
      final response = await http.post(
        Uri.parse('https://noorir.isfpardaz.ir/api.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Dart/2.17 (dart:io)',
        },
        body: {
          'action': 'login',
          'username': _userController.text,
          'password': _passController.text,
          'password2': _isLoginMode ? '' : _pass2Controller.text,
          'mode': _isLoginMode ? 'login' : 'register',
          'app_mode': '1',
        },
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'ok') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_id', data['session_id'] ?? '');
        await prefs.setInt('user_id', data['user_id'] ?? 0);
        await prefs.setString('username', _userController.text);

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        setState(() => _err = data['message'] ?? 'خطا در ورود');
      }
    } catch (e) {
      setState(() => _err = 'خطا در ارتباط با سرور');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2a9d8f), Color(0xFF264653)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send, size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text('Parvaz', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 30),
                  
                  // تب‌های ورود و ثبت نام
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _isLoginMode = true; _err = ''; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isLoginMode ? const Color(0xFF38b2ac) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('ورود', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _isLoginMode = false; _err = ''; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isLoginMode ? const Color(0xFF38b2ac) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('ثبت‌نام', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLoginMode ? 'با نام کاربری و رمز عبور خود وارد شوید.' : 'یک نام کاربری و رمز عبور انتخاب کنید.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _userController,
                    decoration: InputDecoration(
                      hintText: 'نام کاربری',
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'رمز عبور',
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass2Controller,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'تکرار رمز عبور',
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 10),
                  if (_err.isNotEmpty) Text(_err, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _doLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38b2ac),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isLoginMode ? 'ورود' : 'ساخت حساب', style: const TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
