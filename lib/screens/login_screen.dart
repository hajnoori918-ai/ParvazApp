import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
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

    final res = await ApiService.post('login', {
      'username': _userController.text.trim(),
      'password': _passController.text,
      'mode': 'login',
    });

    if (res['status'] == 'ok') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_id', res['session_id'] ?? '');
      await prefs.setInt('user_id', res['user_id'] ?? 0);
      
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } else {
      setState(() => _err = res['message'] ?? 'خطا در ورود');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3390ec),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.send, size: 64, color: Color(0xFF3390ec)),
                  const SizedBox(height: 16),
                  const Text('Parvaz', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3390ec))),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(labelText: 'نام کاربری', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'رمز عبور', border: OutlineInputBorder()),
                  ),
                  if (_err.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_err, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _doLogin,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3390ec)),
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('ورود به حساب', style: TextStyle(fontSize: 16, color: Colors.white)),
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
