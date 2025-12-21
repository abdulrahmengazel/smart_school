// lib/parent_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_setup_screen.dart';
import 'map_screen.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;

  void _openMap(BuildContext context, Map<String, dynamic> attendanceData) {
    GeoPoint? loc = attendanceData['location'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          latitude: loc?.latitude ?? 0.0,
          longitude: loc?.longitude ?? 0.0,
          studentName: attendanceData['name'],
          time: "Live Tracking",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String todayDate = DateTime.now().toString().split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Children Status 🚌"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
            },
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
              String studentId = studentsDocs[index].id; // الآيدي كنص
              String studentName = studentData['name'] ?? "Unknown";

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    // 👇👇👇 هنا المطابقة: نص مع نص 👇👇👇
                    .where('student_id', isEqualTo: studentId)
                    .where('date', isEqualTo: todayDate)
                    .limit(1)
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  // فحص الأخطاء (مهم جداً للفهرس)
                  if (attendanceSnapshot.hasError) {
                    print("Stream Error: ${attendanceSnapshot.error}");
                    return const Text(
                      "Loading Error (Check Console for Index Link)",
                    );
                  }

                  String status = 'Waiting';
                  Map<String, dynamic>? attendanceRecord;

                  if (attendanceSnapshot.hasData &&
                      attendanceSnapshot.data!.docs.isNotEmpty) {
                    attendanceRecord =
                        attendanceSnapshot.data!.docs.first.data()
                            as Map<String, dynamic>;
                    status = attendanceRecord['status'] ?? 'Boarded';
                  }

                  Color statusColor = Colors.orange;
                  String statusText = "Waiting for Bus... ⏳";
                  VoidCallback? onTrackPressed;
                  IconData statusIcon = Icons.hourglass_empty;

                  if (status == 'Boarded') {
                    statusColor = Colors.green;
                    statusText = "On Bus 🚌";
                    statusIcon = Icons.directions_bus;
                    onTrackPressed = () => _openMap(context, attendanceRecord!);
                  } else if (status == 'DroppedOff') {
                    statusColor = Colors.grey;
                    statusText = "Dropped Off 🏠";
                    statusIcon = Icons.check_circle;
                    onTrackPressed = null;
                  }

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.indigo.shade100,
                                child: Text(
                                  studentName[0],
                                  style: const TextStyle(
                                    fontSize: 24,
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
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 30),
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: onTrackPressed,
                              icon: const Icon(Icons.map),
                              label: Text(
                                status == 'Boarded'
                                    ? "TRACK LIVE LOCATION"
                                    : "TRACKING INACTIVE",
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: status == 'Boarded'
                                    ? Colors.indigo
                                    : Colors.grey[300],
                                foregroundColor: status == 'Boarded'
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminSetupScreen(),
                                ),
                              );
                            },
                            child: Text("Go to Admin Setup"),
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
