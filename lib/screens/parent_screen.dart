// lib/screens/parent_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smart_school/controllers/parent_controller.dart';
import 'package:smart_school/screens/schedule_screen.dart';
import 'package:smart_school/screens/assignments_screen.dart';
import 'package:smart_school/screens/exam_results_screen.dart';
import 'package:smart_school/screens/map_screen.dart';
import 'package:smart_school/screens/notifications_screen.dart';
import 'package:smart_school/services/auth_service.dart';
import 'package:smart_school/screens/login_screen.dart';

/// شاشة الوالدين الرئيسية: تعرض قائمة بالأبناء وحالتهم في الحافلة والمهام الدراسية
class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  late ParentController _controller;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _controller = ParentController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// وظيفة تسجيل الخروج والعودة لشاشة الدخول
  void _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _openMap(BuildContext context, Map<String, dynamic> attendanceData) {
    GeoPoint? startLoc = attendanceData['location'];
    GeoPoint? endLoc = attendanceData['drop_off_location'];
    String busId = attendanceData['bus_id'] ?? 'unknown_bus';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          startLat: startLoc?.latitude ?? 0.0,
          startLng: startLoc?.longitude ?? 0.0,
          dropOffLoc: endLoc,
          studentName: attendanceData['name'],
          busId: busId,
        ),
      ),
    );
  }

  Widget _buildTripRow(
    String title,
    IconData icon,
    Map<String, dynamic>? record,
    VoidCallback? onTap,
    ColorScheme colorScheme,
  ) {
    var statusDetails = _controller.getTripStatusDetails(record);
    Color color = statusDetails['color'];
    String statusText = statusDetails['statusText'];
    bool hasTap = statusDetails['hasTap'];

    return InkWell(
      onTap: hasTap ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: record != null ? color : colorScheme.secondary, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  statusText,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            if (record != null)
              Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.secondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        String formattedDate = _controller.getFormattedDate();
        bool isToday = _controller.isToday();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Children Status 🚌", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  isToday
                      ? "Today, ${DateFormat('MMM d').format(_controller.selectedDate)}"
                      : DateFormat('EEE, MMM d, y').format(_controller.selectedDate),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: colorScheme.secondary),
                ),
              ],
            ),
            actions: [
              StreamBuilder<int>(
                stream: _controller.getUnreadNotificationsCount(),
                builder: (context, snapshot) {
                  int count = snapshot.data ?? 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => _controller.pickDate(context),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: "Logout",
                onPressed: () {
                  // إظهار حوار تأكيد قبل تسجيل الخروج
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Logout"),
                      content: const Text("Are you sure you want to sign out?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                        TextButton(onPressed: _logout, child: const Text("Logout", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _controller.getStudentsStream(),
            builder: (context, studentSnapshot) {
              if (studentSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!studentSnapshot.hasData || studentSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text("No children linked.", style: TextStyle(color: colorScheme.secondary)),
                );
              }

              var studentsDocs = studentSnapshot.data!.docs;

              return ListView.builder(
                itemCount: studentsDocs.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  var studentData = studentsDocs[index].data() as Map<String, dynamic>;
                  String studentId = studentsDocs[index].id;
                  String studentName = studentData['name'] ?? "Unknown";

                  return StreamBuilder<QuerySnapshot>(
                    stream: _controller.getAttendanceStream(studentId, formattedDate),
                    builder: (context, attendanceSnapshot) {
                      Map<String, dynamic>? morningRecord;
                      Map<String, dynamic>? afternoonRecord;

                      if (attendanceSnapshot.hasData) {
                        _controller.parseAttendanceRecords(
                          attendanceSnapshot.data!,
                          onMorning: (record) => morningRecord = record,
                          onAfternoon: (record) => afternoonRecord = record,
                        );
                      }

                      return Card(
                        color: colorScheme.primaryContainer,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: colorScheme.primary,
                                    child: Text(studentName[0], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onPrimary)),
                                  ),
                                  const SizedBox(width: 15),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(studentName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      Text("Grade: ${studentData['grade'] ?? 'N/A'}", style: TextStyle(color: colorScheme.secondary, fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        String classId = studentData['class_id'] ?? '';
                                        String className = studentData['class_name'] ?? 'Class';
                                        if (classId.isNotEmpty) {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => ScheduleScreen(classId: classId, className: className)));
                                        }
                                      },
                                      icon: const Icon(Icons.calendar_today, size: 16),
                                      label: const Text("SCHEDULE"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        String classId = studentData['class_id'] ?? '';
                                        String className = studentData['class_name'] ?? 'Class';
                                        if (classId.isNotEmpty) {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => AssignmentsScreen(classId: classId, className: className)));
                                        }
                                      },
                                      icon: const Icon(Icons.assignment_outlined, size: 16),
                                      label: const Text("HOMEWORK"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colorScheme.secondary,
                                        side: BorderSide(color: colorScheme.secondary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    bool success = await _controller.requestAbsence(context, studentId, studentName);
                                    if (success) _showMessage("✅ Absence recorded");
                                  },
                                  icon: const Icon(Icons.sick_outlined, size: 20, color: Colors.redAccent),
                                  label: const Text("REPORT ABSENCE / SICK LEAVE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExamResultsScreen(studentId: studentId, studentName: studentName))),
                                  icon: const Icon(Icons.school_outlined),
                                  label: const Text("VIEW EXAM RESULTS 🎓"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.secondary,
                                    foregroundColor: colorScheme.onSurface,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const Divider(height: 30, color: Colors.white10),
                              _buildTripRow("Morning (To School)", Icons.wb_sunny_outlined, morningRecord, morningRecord != null ? () => _openMap(context, morningRecord!) : null, colorScheme),
                              _buildTripRow("Afternoon (To Home)", Icons.home_outlined, afternoonRecord, afternoonRecord != null ? () => _openMap(context, afternoonRecord!) : null, colorScheme),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
