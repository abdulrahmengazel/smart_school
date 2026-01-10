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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // نقطة البداية هي شاشة تسجيل الدخول
      home: const LoginScreen(),
    );
  }
}
