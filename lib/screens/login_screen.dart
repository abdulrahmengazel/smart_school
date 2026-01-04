// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_school/services/auth_service.dart';
import 'package:smart_school/screens/parent_screen.dart';
import 'package:smart_school/screens/driver_screen.dart';
import 'package:smart_school/screens/admin_dashboard_screen.dart';

/// شاشة تسجيل الدخول: الواجهة الأولى التي تظهر للمستخدم للوصول إلى النظام
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  /// وظيفة تسجيل الدخول والتحقق من دور المستخدم (والد، سائق، مسؤول) للانتقال للشاشة المناسبة
  void _login() async {
    setState(() => _isLoading = true);
    
    final user = await _authService.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (user != null) {
      final role = await _authService.getUserRole(user.uid);
      if (!mounted) return;

      Widget nextScreen;
      if (role == 'parent') {
        nextScreen = const ParentScreen();
      } else if (role == 'driver') {
        nextScreen = const DriverScreen();
      } else if (role == 'admin') {
        nextScreen = const AdminDashboardScreen();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: User role not found.")),
        );
        setState(() => _isLoading = false);
        return;
      }

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => nextScreen));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed. Please check your credentials.")),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school, size: 100, color: colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  "Smart School",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
                Text(
                  "Empowering Safety & Education",
                  style: TextStyle(fontSize: 14, color: colorScheme.secondary),
                ),
                const SizedBox(height: 50),
                
                // حقل البريد الإلكتروني
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: Icon(Icons.email_outlined, color: colorScheme.secondary),
                    filled: true,
                    fillColor: colorScheme.primaryContainer.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                
                // حقل كلمة المرور
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock_outline, color: colorScheme.secondary),
                    filled: true,
                    fillColor: colorScheme.primaryContainer.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 30),
                
                // زر تسجيل الدخول
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
