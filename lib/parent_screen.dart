import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'map_screen.dart'; // 👈 استدعاء الملف الجديد
import 'services/auth_service.dart';
import 'login_screen.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;

  void _openMap(
    BuildContext context,
    double lat,
    double lng,
    String name,
    String time,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          latitude: lat,
          longitude: lng,
          studentName: name,
          time: time,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Children 👨‍👩‍👦"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      // 1. أولاً: نجلب قائمة الطلاب المرتبطين بهذا الأب
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .where('parent_uid', isEqualTo: _currentUserUid) // 👈 السر هنا
            .snapshots(),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!studentSnapshot.hasData || studentSnapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No children linked to this account."),
            );
          }

          // قائمة أرقام الطلاب (IDs) التابعين للأب
          List<int> studentIds = studentSnapshot.data!.docs
              .map((doc) => int.parse(doc.id))
              .toList();

          // 2. ثانياً: نجلب سجلات الحضور لهؤلاء الطلاب فقط
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where(
                  'student_id',
                  whereIn: studentIds,
                ) // 👈 جلب الحضور لهذه القائمة فقط
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, attendanceSnapshot) {
              if (attendanceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!attendanceSnapshot.hasData ||
                  attendanceSnapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("No attendance records today."),
                );
              }

              final docs = attendanceSnapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  // الكود القديم لعرض البطاقة (نفسه تماماً)
                  Timestamp? timestamp = data['timestamp'];
                  String timeStr = timestamp != null
                      ? DateFormat('hh:mm a').format(timestamp.toDate())
                      : "--:--";
                  String dateStr = timestamp != null
                      ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                      : "Unknown Date";
                  bool isPresent = data['status'] == 'Present';
                  GeoPoint? location = data['location'];

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: InkWell(
                      onTap: location != null
                          ? () => _openMap(
                              context,
                              location.latitude,
                              location.longitude,
                              data['name'],
                              timeStr,
                            )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPresent ? Icons.check_circle : Icons.cancel,
                                color: isPresent ? Colors.green : Colors.red,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? "Unknown", // اسم الطالب
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    isPresent ? "Arrived Safely ✅" : "Absent ❌",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (location != null)
                                    Text(
                                      "Tap to track 📍",
                                      style: TextStyle(
                                        color: Colors.indigo[300],
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.indigo,
                                  ),
                                ),
                                const Text(
                                  "TIME",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
