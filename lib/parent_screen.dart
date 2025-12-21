// lib/parent_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smart_school/schedule_screen.dart';
import 'assignments_screen.dart';
import 'exam_results_screen.dart';
import 'map_screen.dart';
import 'notifications_screen.dart';

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
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.indigo),
        ),
        child: child!,
      ),
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

  // دالة طلب الغياب
  Future<void> _requestAbsence(String studentId, String studentName) async {
    // 1. اختيار التاريخ
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      // الافتراضي غداً
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: "Select Absence Date 📅",
    );

    if (pickedDate == null) return;

    String dateStr = pickedDate.toString().split(' ')[0];

    // 2. تأكيد الطلب
    if (!mounted) return;
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Absence recorded for $dateStr"),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // ودجت صغيرة لعرض سطر الرحلة (صباحي أو مسائي)
  Widget _buildTripRow(
    String title,
    IconData icon,
    Map<String, dynamic>? record,
  ) {
    String status = record?['status'] ?? 'Waiting';
    bool hasRecord = record != null;

    Color color;
    String statusText;
    VoidCallback? onTap;

    if (!hasRecord) {
      color = Colors.grey;
      statusText = "No record yet";
      onTap = null;
    } else if (status == 'Boarded') {
      color = Colors.green;
      statusText = "On Bus (Live) 📍";
      onTap = () => _openMap(context, record);
    } else if (status == 'DroppedOff') {
      color = Colors.indigo;
      String time = "";
      if (record['drop_off_time'] != null) {
        time = DateFormat(
          'h:mm a',
        ).format((record['drop_off_time'] as Timestamp).toDate());
      }
      statusText = "Arrived ($time) ✅";
      onTap = () => _openMap(context, record); // لرؤية التفاصيل
    } else {
      color = Colors.orange;
      statusText = "Waiting...";
      onTap = null;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: hasRecord ? color : Colors.grey, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (hasRecord)
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('parent_uid', isEqualTo: _currentUserUid)
                .where('is_read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) count = snapshot.data!.docs.length;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      // الانتقال لشاشة الإشعارات
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
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

          var studentsDocs = studentSnapshot.data!.docs;

          return ListView.builder(
            itemCount: studentsDocs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              var studentData =
                  studentsDocs[index].data() as Map<String, dynamic>;
              String studentId = studentsDocs[index].id;
              String studentName = studentData['name'] ?? "Unknown";

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('student_id', isEqualTo: studentId)
                    .where('date', isEqualTo: formattedDate)
                    .orderBy('timestamp', descending: true) // نجلب الكل مرتبين
                    .snapshots(), // 👈 أزلنا limit(1)
                builder: (context, attendanceSnapshot) {
                  Map<String, dynamic>? morningRecord;
                  Map<String, dynamic>? afternoonRecord;

                  if (attendanceSnapshot.hasData &&
                      attendanceSnapshot.data!.docs.isNotEmpty) {
                    var docs = attendanceSnapshot.data!.docs;

                    // تصفية السجلات حسب نوع الرحلة
                    try {
                      var morningDoc = docs.firstWhere(
                        (d) => d['trip_type'] == 'pickup',
                      );
                      morningRecord = morningDoc.data() as Map<String, dynamic>;
                    } catch (e) {
                      /* No morning trip */
                    }

                    try {
                      var afternoonDoc = docs.firstWhere(
                        (d) => d['trip_type'] == 'dropoff',
                      );
                      afternoonRecord =
                          afternoonDoc.data() as Map<String, dynamic>;
                    } catch (e) {
                      /* No afternoon trip */
                    }
                  }

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // رأس الكرت (اسم الطالب)
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.indigo.shade100,
                                child: Text(
                                  studentName[0],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Grade: ${studentData['grade'] ?? 'N/A'}",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // زر فتح الجدول الدراسي
                          const SizedBox(height: 15),

                          // صف يحتوي على الزرين (الجدول + الواجبات)
                          Row(
                            children: [
                              // 1. زر الجدول
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    String classId =
                                        studentData['class_id'] ?? '';
                                    String className =
                                        studentData['class_name'] ?? 'Class';
                                    if (classId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ScheduleScreen(
                                            classId: classId,
                                            className: className,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.calendar_month,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "SCHEDULE",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.indigo,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // 2. زر الواجبات (الجديد)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    // تأكد من استيراد ملف assignments_screen.dart في الأعلى
                                    String classId =
                                        studentData['class_id'] ?? '';
                                    String className =
                                        studentData['class_name'] ?? 'Class';
                                    if (classId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AssignmentsScreen(
                                                classId: classId,
                                                className: className,
                                              ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.assignment, size: 18),
                                  label: const Text(
                                    "HOMEWORK",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.deepOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // ... تحت صف الأزرار السابق (Schedule & Homework) ...
                          const SizedBox(height: 10),

                          // زر الإبلاغ عن غياب
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _requestAbsence(studentId, studentName),
                              icon: const Icon(
                                Icons.sick,
                                size: 20,
                                color: Colors.redAccent,
                              ),
                              label: const Text(
                                "REPORT ABSENCE / SICK LEAVE",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // زر نتائج الامتحانات
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExamResultsScreen(
                                      studentId: studentId,
                                      studentName: studentName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.school),
                              label: const Text("VIEW EXAM RESULTS 🎓"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),

                          const Divider(height: 25),

                          // 1. الرحلة الصباحية (Pickup)
                          _buildTripRow(
                            "Morning Trip (To School)",
                            Icons.wb_sunny,
                            morningRecord,
                          ),

                          // 2. الرحلة المسائية (Dropoff)
                          _buildTripRow(
                            "Afternoon Trip (To Home)",
                            Icons.nights_stay,
                            afternoonRecord,
                          ),
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
