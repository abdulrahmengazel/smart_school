// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'services/firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        // Using the user-specified color palette
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF415A77),
          primary: const Color(0xFF415A77),
          secondary: const Color(0xFF778DA9),
          surface: const Color(0xFF0D1B2A),
          onSurface: const Color(0xFFE0E1DD),
          primaryContainer: const Color(0xFF1B263B),
          onPrimaryContainer: const Color(0xFFE0E1DD),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1B2A),
          foregroundColor: Color(0xFFE0E1DD),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE0E1DD)),
          bodyMedium: TextStyle(color: Color(0xFFE0E1DD)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
