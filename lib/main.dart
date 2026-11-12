import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ParvazApp());
}

class ParvazApp extends StatelessWidget {
  const ParvazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parvaz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3390ec)),
        useMaterial3: true,
      ),
      locale: const Locale('fa', 'IR'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const LoginScreen(),
    );
  }
}
