// lib/parent_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smart_school/screens/schedule_screen.dart';
import 'package:smart_school/screens/assignments_screen.dart';
import 'package:smart_school/screens/exam_results_screen.dart';
import 'package:smart_school/screens/map_screen.dart';
import 'package:smart_school/screens/notifications_screen.dart';
import 'package:smart_school/services/auth_service.dart';
import 'package:smart_school/screens/login_screen.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
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

  Future<void> _requestAbsence(String studentId, String studentName) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: "Select Absence Date 📅",
    );

    if (pickedDate == null) return;

    String dateStr = pickedDate.toString().split(' ')[0];

    if (!mounted) return;
    final theme = Theme.of(context);
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Absence"),
        content: Text("Mark $studentName as absent on $dateStr?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('leaves').add({
          'student_id': studentId,
          'student_name': studentName,
          'parent_uid': _currentUserUid,
          'date': dateStr,
          'reason': 'Parent Request',
          'created_at': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Absence recorded for $dateStr"),
            backgroundColor: theme.colorScheme.secondary,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _buildTripRow(
    String title,
    IconData icon,
    Map<String, dynamic>? record,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String status = record?['status'] ?? 'Waiting';
    bool hasRecord = record != null;

    Color color;
    String statusText;
    VoidCallback? onTap;

    if (!hasRecord) {
      color = colorScheme.onSurface.withOpacity(0.5);
      statusText = "No record yet";
    } else if (status == 'Boarded') {
      color = colorScheme.tertiary;
      statusText = "On Bus (Live) 📍";
      onTap = () => _openMap(context, record);
    } else if (status == 'DroppedOff') {
      color = colorScheme.primary;
      String time = "";
      if (record['drop_off_time'] != null) {
        time = DateFormat('h:mm a').format((record['drop_off_time'] as Timestamp).toDate());
      }
      statusText = "Arrived ($time) ✅";
      onTap = () => _openMap(context, record);
    } else {
      color = colorScheme.secondary;
      statusText = "Waiting...";
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.primaryContainer),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(
                    statusText,
                    style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String formattedDate = _selectedDate.toString().split(' ')[0];
    bool isToday = formattedDate == DateTime.now().toString().split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Children Status 🚌", style: TextStyle(fontSize: 18)),
            Text(
              isToday
                  ? "Today, ${DateFormat('MMM d').format(_selectedDate)}"
                  : DateFormat('EEE, MMM d, y').format(_selectedDate),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('parent_uid', isEqualTo: _currentUserUid)
                .where('is_read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int count = snapshot.data?.docs.length ?? 0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
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
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: TextStyle(color: colorScheme.onError, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .where('parent_uid', isEqualTo: _currentUserUid)
            .snapshots(),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!studentSnapshot.hasData || studentSnapshot.data!.docs.isEmpty)
            return const Center(child: Text("No children linked."));

          return ListView.builder(
            itemCount: studentSnapshot.data!.docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              var studentDoc = studentSnapshot.data!.docs[index];
              var studentData = studentDoc.data() as Map<String, dynamic>;
              String studentName = studentData['name'] ?? "Unknown";

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('student_id', isEqualTo: studentDoc.id)
                    .where('date', isEqualTo: formattedDate)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  Map<String, dynamic>? morningRecord;
                  Map<String, dynamic>? afternoonRecord;

                  if (attendanceSnapshot.hasData && attendanceSnapshot.data!.docs.isNotEmpty) {
                    for (var doc in attendanceSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['trip_type'] == 'pickup') morningRecord = data;
                      if (data['trip_type'] == 'dropoff') afternoonRecord = data;
                    }
                  }

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  studentName.isNotEmpty ? studentName[0] : '?',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(studentName, style: theme.textTheme.titleLarge),
                                  Text(
                                    "Grade: ${studentData['grade'] ?? 'N/A'}",
                                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    String classId = studentData['class_id'] ?? '';
                                    if (classId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ScheduleScreen(
                                            classId: classId,
                                            className: studentData['class_name'] ?? 'Class',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_month, size: 18),
                                  label: const Text("SCHEDULE", style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    String classId = studentData['class_id'] ?? '';
                                    if (classId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AssignmentsScreen(
                                            classId: classId,
                                            className: studentData['class_name'] ?? 'Class',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.assignment, size: 18),
                                  label: const Text("HOMEWORK", style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => _requestAbsence(studentDoc.id, studentName),
                              icon: Icon(Icons.sick, size: 20, color: colorScheme.error),
                              label: Text("REPORT ABSENCE / SICK LEAVE", style: TextStyle(color: colorScheme.error)),
                              style: TextButton.styleFrom(
                                backgroundColor: colorScheme.errorContainer.withOpacity(0.3),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExamResultsScreen(
                                      studentId: studentDoc.id,
                                      studentName: studentName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.school),
                              label: const Text("VIEW EXAM RESULTS 🎓"),
                            ),
                          ),
                          const Divider(height: 25),
                          _buildTripRow("Morning Trip (To School)", Icons.wb_sunny, morningRecord),
                          _buildTripRow("Afternoon Trip (To Home)", Icons.nights_stay, afternoonRecord),
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
  }
}
