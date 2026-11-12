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
  bool _isLoading = false;
  String _err = '';

  Future<void> _doLogin() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;
    setState(() { _isLoading = true; _err = ''; });

    try {
      final response = await http.post(
        Uri.parse('https://noorir.isfpardaz.ir/api.php'),
        body: {
          'action': 'login',
          'username': _userController.text,
          'password': _passController.text,
          'mode': 'login',
          'app_mode': '1', // این خط برای شناسایی اپلیکیشن اضافه شد
        },
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'ok') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', _userController.text);
        await prefs.setString('password', _passController.text);
        await prefs.setString('session_id', data['session_id'] ?? ''); // ذخیره سشن
        await prefs.setInt('user_id', data['user_id'] ?? 0); // ذخیره آیدی کاربر

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
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF2a9d8f), Color(0xFF264653)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text('Parvaz', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 40),
                TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    hintText: 'نام کاربری',
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'رمز عبور',
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                if (_err.isNotEmpty) Text(_err, style: const TextStyle(color: Colors.redAccent)),
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
                        : const Text('ورود', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
