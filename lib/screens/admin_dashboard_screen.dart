// lib/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_school/controllers/admin_controller.dart';

/// لوحة تحكم المسؤول: تتيح توليد البيانات التجريبية وإدارة النظام
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late AdminController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// وظيفة مساعدة لعرض رسالة (SnackBar)
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// بناء بطاقة (Card) لكل عملية إدارية
  Widget _buildAdminCard(
    String title,
    IconData icon,
    Color color,
    Future<String> Function() action,
  ) {
    return Card(
      elevation: 2,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: _controller.isLoading
            ? null
            : () async {
                String result = await action();
                _showSnack(result);
              },
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Admin Dashboard 🛠️"),
            backgroundColor: Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      // قسم البنية التحتية
                      _buildAdminCard(
                        "1. Generate Classes",
                        Icons.school,
                        Colors.blue,
                        _controller.seedClasses,
                      ),
                      _buildAdminCard(
                        "2. Generate Routes",
                        Icons.directions_bus,
                        Colors.orangeAccent,
                        _controller.seedBusRoutes,
                      ),

                      // قسم إعداد الطلاب
                      _buildAdminCard(
                        "3. Assign Class/Bus",
                        Icons.link,
                        Colors.cyan,
                        _controller.assignStudents,
                      ),
                      _buildAdminCard(
                        "4. Link Students to ME",
                        Icons.person_pin,
                        Colors.purpleAccent,
                        _controller.linkStudentsToMe,
                      ),

                      // القسم الأكاديمي
                      _buildAdminCard(
                        "5. Generate Schedules",
                        Icons.calendar_month,
                        Colors.amber.shade700,
                        _controller.seedSchedules,
                      ),
                      _buildAdminCard(
                        "6. Generate Homework",
                        Icons.assignment,
                        Colors.pinkAccent,
                        _controller.seedAssignments,
                      ),
                      _buildAdminCard(
                        "7. Publish Grades",
                        Icons.score,
                        Colors.greenAccent.shade700,
                        _controller.seedExamResults,
                      ),

                      // قسم إعادة الضبط
                      _buildAdminCard(
                        "Reset Attendance",
                        Icons.delete_forever,
                        Colors.redAccent,
                        _controller.clearAttendance,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
