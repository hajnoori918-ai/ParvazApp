import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://noorir.isfpardaz.ir/api.php';

  static Future<Map<String, dynamic>> post(String action, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id') ?? '';

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Session-ID': sessionId,
        },
        body: {
          'action': action,
          'app_mode': '1',
          ...data,
        },
      );

      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'status': 'error', 'message': 'خطا در ارتباط با سرور: $e'};
    }
  }
}
