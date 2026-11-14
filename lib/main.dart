import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api_service.dart';
import 'common.dart';
import 'home_screen.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.i.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const ParvazApp());
}

class ParvazApp extends StatelessWidget {
  const ParvazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PTheme>(
      valueListenable: themeN,
      builder: (context, t, _) {
        final base = t.dark ? ThemeData.dark(useMaterial3: false) : ThemeData.light(useMaterial3: false);
        return MaterialApp(
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          title: 'Parvaz',
          locale: const Locale('fa', 'IR'),
          supportedLocales: const [Locale('fa', 'IR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: base.copyWith(
            scaffoldBackgroundColor: t.bg,
            canvasColor: t.panel,
            primaryColor: t.accent,
            colorScheme: base.colorScheme.copyWith(primary: t.accent, secondary: t.accent, surface: t.panel),
            textTheme: base.textTheme.apply(bodyColor: t.text, displayColor: t.text),
            splashFactory: InkRipple.splashFactory,
            textSelectionTheme: TextSelectionThemeData(cursorColor: t.accent, selectionHandleColor: t.accent),
          ),
          home: const Splash(),
        );
      },
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  String? err;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    setState(() {
      loading = true;
      err = null;
    });
    var authGuard = false;
    Api.i.onAuthLost = () {
      if (authGuard) return;
      authGuard = true;
      Api.i.boot().then((_) {
        navKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
        authGuard = false;
      });
    };
    final j = await Api.i.boot();
    if (!mounted) return;
    if (j['status'] != 'ok') {
      setState(() {
        loading = false;
        err = (j['message'] ?? 'اتصال به سرور برقرار نیست.').toString();
      });
      return;
    }
    applyCfg(j);
    
    // این خط تغییر کرد تا دیگر به ME نیاز نداشته باشد
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => (j['me'] == null) ? const LoginScreen() : const HomeScreen()));
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
      _go();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF264653),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A9D8F), Color(0xFF264653)])),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // اینجا errorBuilder اضافه شد تا اگر عکس نبود، برنامه ارور نده
          ClipRRect(
            borderRadius: BorderRadius.circular(22), 
            child: Image.asset(
              'assets/icon.png', 
              width: 96, 
              height: 96,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.send, size: 96, color: Colors.white),
            )
          ),
          const SizedBox(height: 14),
          const Text('Parvaz', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: .5)),
          const SizedBox(height: 26),
          if (loading) const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
          if (err != null) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(err!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.8))),
            const SizedBox(height: 14),
            Row(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton(onPressed: _go, child: const Text('تلاش دوباره')),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: _editServer, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)), child: const Text('آدرس سرور')),
            ]),
          ],
        ]),
      ),
    );
  }
}
