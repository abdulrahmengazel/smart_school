import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_school/admin_setup_screen.dart';import 'admin_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'parent_screen.dart'; // لاستيراد شاشة الأب
import 'driver_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    User? user = await _authService.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (user != null) {
      // 1. نجاح الدخول -> نفحص الدور
      String role = await _authService.getUserRole(user.uid);

      if (!mounted) return;

      if (role == 'driver') {
        // توجيه للسائق
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DriverScreen()),
        );
      } else {
        // توجيه لولي الأمر
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ParentScreen()),
        );
      }
    } else {
      setState(() {
        _errorMessage = "Invalid email or password";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, size: 80, color: Colors.teal),
              const SizedBox(height: 20),
              const Text(
                "Smart School",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("LOGIN", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 20),

              // زر الدخول العادي
              ElevatedButton(
                onPressed: _login,
                // ... بقية خصائص الزر ...
                child: const Text("LOGIN"),
              ),

              const SizedBox(height: 30),

              // 👇 زر الأدمن السري (للمطورين)
              TextButton.icon(
                onPressed: () {
                  // يجب أن تكون مسجلاً للدخول لتنفيذ عمليات الأدمن،
                  // أو يمكنك تجاوز التحقق مؤقتاً إذا كنت فقط تريد رؤية الواجهة
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDashboardScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.blueGrey,
                ),
                label: const Text(
                  "Admin Dashboard (Dev Only)",
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ),

              // مثال لزر مؤقت
            ],
          ),
        ),
      ),
    );
  }
}
