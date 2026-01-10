// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'services/firebase_options.dart';
import 'screens/login_screen.dart'; // تأكد أن هذا موجود لاستدعاء شاشة الدخول

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الفايربيس
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const SmartSchoolApp());
}

class SmartSchoolApp extends StatelessWidget {
  const SmartSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart School',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2e46c3), // from d2e46c3
          primary: const Color(0xFF2e46c3),
          secondary: const Color(0xFF83b0ec), // from 183b0ec
          tertiary: const Color(0xFFc4fcae), // from fc4fcae
          surface: const Color(0xFF0d1b2a),
          onSurface: const Color(0xFFe0e1dd),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0d1b2a),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0d1b2a),
          foregroundColor: Color(0xFFe0e1dd),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFe0e1dd)),
          bodyMedium: TextStyle(color: Color(0xFFe0e1dd)),
          displayLarge: TextStyle(color: Color(0xFFe0e1dd)),
          displayMedium: TextStyle(color: Color(0xFFe0e1dd)),
          displaySmall: TextStyle(color: Color(0xFFe0e1dd)),
          headlineLarge: TextStyle(color: Color(0xFFe0e1dd)),
          headlineMedium: TextStyle(color: Color(0xFFe0e1dd)),
          headlineSmall: TextStyle(color: Color(0xFFe0e1dd)),
          titleLarge: TextStyle(color: Color(0xFFe0e1dd)),
          titleMedium: TextStyle(color: Color(0xFFe0e1dd)),
          titleSmall: TextStyle(color: Color(0xFFe0e1dd)),
          bodySmall: TextStyle(color: Color(0xFFe0e1dd)),
          labelLarge: TextStyle(color: Color(0xFFe0e1dd)),
          labelMedium: TextStyle(color: Color(0xFFe0e1dd)),
          labelSmall: TextStyle(color: Color(0xFFe0e1dd)),
        ),
      ),
      // نقطة البداية هي شاشة تسجيل الدخول
      home: const LoginScreen(),
    );
  }
}
