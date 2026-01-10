// lib/schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleScreen extends StatelessWidget {
  final String classId;
  final String className;

  const ScheduleScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    // ترتيب الأيام لضمان ظهورها بشكل صحيح
    final List<String> orderedDays = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("$className Schedule 📅"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // نبحث مباشرة باستخدام الـ ID لأننا استخدمناه كـ Document ID أثناء الإنشاء
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .doc(classId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey),
                  Text(
                    "No schedule published yet.",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // جلب البيانات
          var data = snapshot.data!.data() as Map<String, dynamic>;
          Map<String, dynamic> daysMap = data['days'] ?? {};

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orderedDays.length,
            itemBuilder: (context, index) {
              String dayName = orderedDays[index];
              List<dynamic> sessions = daysMap[dayName] ?? [];

              if (sessions.isEmpty)
                return const SizedBox(); // تخطي الأيام الفارغة

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dayName.substring(0, 3).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                  title: Text(
                    dayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${sessions.length} Classes"),
                  children: sessions.map((session) {
                    return ListTile(
                      leading: const Icon(Icons.class_, color: Colors.orange),
                      title: Text(
                        session['subject'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(session['time']),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.grey,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

