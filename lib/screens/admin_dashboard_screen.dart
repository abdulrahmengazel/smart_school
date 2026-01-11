// lib/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_school/services/auth_service.dart';
import 'package:smart_school/screens/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _seedClasses() async {
    setState(() => _isLoading = true);
    List<String> classes = ["Grade 10-A", "Grade 10-B", "Grade 11-A", "Grade 11-B", "Grade 12-A"];
    WriteBatch batch = _firestore.batch();
    for (String className in classes) {
      DocumentReference ref = _firestore.collection('classes').doc();
      batch.set(ref, {
        'name': className,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    _showSnack("✅ Classes Generated!");
    setState(() => _isLoading = false);
  }

  Future<void> _seedBusRoutes() async {
    setState(() => _isLoading = true);
    String currentDriverId = FirebaseAuth.instance.currentUser?.uid ?? "unknown_driver";
    List<Map<String, dynamic>> routes = [
      {
        'route_name': 'North Route (City Center)',
        'plate_number': 'ABC-123',
        'driver_id': currentDriverId,
        'capacity': 25,
      },
      {
        'route_name': 'South Route (Flower Dist)',
        'plate_number': 'XYZ-999',
        'driver_id': 'driver_02',
        'capacity': 30,
      },
      {
        'route_name': 'East Route (Industrial Area)',
        'plate_number': 'DXB-555',
        'driver_id': 'driver_03_uid',
        'capacity': 20,
      },
    ];
    WriteBatch batch = _firestore.batch();
    for (var route in routes) {
      DocumentReference ref = _firestore.collection('bus_routes').doc();
      batch.set(ref, {...route, 'created_at': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    _showSnack("✅ Bus Routes Generated!");
    setState(() => _isLoading = false);
  }

  Future<void> _assignStudentsToClassesAndRoutes() async {
    setState(() => _isLoading = true);
    try {
      var classesSnapshot = await _firestore.collection('classes').get();
      var routesSnapshot = await _firestore.collection('bus_routes').get();
      var studentsSnapshot = await _firestore.collection('students').get();

      if (classesSnapshot.docs.isEmpty || routesSnapshot.docs.isEmpty) {
        _showSnack("❌ No classes or routes found!");
        setState(() => _isLoading = false);
        return;
      }

      List<String> classIds = classesSnapshot.docs.map((e) => e.id).toList();
      List<String> classNames = classesSnapshot.docs.map((e) => e['name'] as String).toList();

      List<Map<String, dynamic>> routesData = routesSnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['route_name'],
        'plate': doc['plate_number'],
      }).toList();

      WriteBatch batch = _firestore.batch();
      int i = 0;

      for (var studentDoc in studentsSnapshot.docs) {
        int classIndex = i % classIds.length;
        int routeIndex = i % routesData.length;

        batch.update(studentDoc.reference, {
          'class_id': classIds[classIndex],
          'class_name': classNames[classIndex],
          'bus_id': routesData[routeIndex]['id'],
          'route_name': routesData[routeIndex]['name'],
          'bus_plate': routesData[routeIndex]['plate'],
        });
        i++;
      }
      await batch.commit();
      _showSnack("✅ Assigned ${studentsSnapshot.docs.length} students!");
    } catch (e) {
      _showSnack("Error: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _linkStudentsToMe() async {
    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack("⚠️ Not logged in!");
      setState(() => _isLoading = false);
      return;
    }

    var students = await _firestore.collection('students').get();
    WriteBatch batch = _firestore.batch();
    for (var doc in students.docs) {
      batch.update(doc.reference, {'parent_uid': user.uid});
    }
    await batch.commit();
    _showSnack("✅ All students linked to YOU!");
    setState(() => _isLoading = false);
  }

  Future<void> _seedSchedules() async {
    setState(() => _isLoading = true);
    try {
      var classesSnapshot = await _firestore.collection('classes').get();
      if (classesSnapshot.docs.isEmpty) {
        _showSnack("⚠️ No classes found. Please generate classes first.");
        setState(() => _isLoading = false);
        return;
      }

      WriteBatch batch = _firestore.batch();
      List<String> weekDays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday"];
      List<String> subjects = ["Math", "Physics", "Chemistry", "English", "History", "CS", "Biology"];

      for (var classDoc in classesSnapshot.docs) {
        Map<String, dynamic> daysSchedule = {};
        for (var day in weekDays) {
          subjects.shuffle();
          daysSchedule[day] = [
            {"subject": subjects[0], "time": "08:00 - 09:00"},
            {"subject": subjects[1], "time": "09:00 - 10:00"},
            {"subject": subjects[2], "time": "10:30 - 11:30"},
          ];
        }
        batch.set(_firestore.collection('schedules').doc(classDoc.id), {
          'class_id': classDoc.id,
          'class_name': classDoc['name'],
          'days': daysSchedule,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      _showSnack("✅ Class Schedules Generated!");
    } catch (e) {
      _showSnack("Error: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _seedAssignments() async {
    setState(() => _isLoading = true);
    try {
      var classesSnapshot = await _firestore.collection('classes').get();
      if (classesSnapshot.docs.isEmpty) {
        _showSnack("❌ No classes found!");
        setState(() => _isLoading = false);
        return;
      }

      WriteBatch batch = _firestore.batch();
      List<String> subjects = ["Math", "Physics", "English", "Science"];

      for (var classDoc in classesSnapshot.docs) {
        for (int i = 1; i <= 3; i++) {
          DateTime dueDate = DateTime.now().add(Duration(days: i + 2));
          batch.set(_firestore.collection('assignments').doc(), {
            'class_id': classDoc.id,
            'class_name': classDoc['name'],
            'subject': subjects[i % subjects.length],
            'title': 'Homework #$i: ${subjects[i % subjects.length]} Basics',
            'description': 'Please solve page ${10 * i} to ${10 * i + 2}.',
            'attachment_url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
            'created_at': FieldValue.serverTimestamp(),
            'due_date': Timestamp.fromDate(dueDate),
          });
        }
      }
      await batch.commit();
      _showSnack("✅ Assignments Generated successfully!");
    } catch (e) {
      _showSnack("Error: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _seedExamResults() async {
    setState(() => _isLoading = true);
    try {
      var studentsSnapshot = await _firestore.collection('students').get();
      if (studentsSnapshot.docs.isEmpty) {
        _showSnack("❌ No students found!");
        setState(() => _isLoading = false);
        return;
      }

      WriteBatch batch = _firestore.batch();
      List<String> subjects = ["Math", "Physics", "Chemistry", "English", "Biology", "History"];
      List<String> examTypes = ["Midterm Exam", "Final Exam"];

      for (var student in studentsSnapshot.docs) {
        for (var subject in subjects) {
          String type = examTypes[DateTime.now().millisecond % 2];
          int score = 60 + (DateTime.now().microsecond % 41);
          batch.set(_firestore.collection('exam_results').doc(), {
            'student_id': student.id,
            'student_name': student['name'],
            'subject': subject,
            'exam_type': type,
            'score': score,
            'max_score': 100,
            'date': FieldValue.serverTimestamp(),
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
      _showSnack("✅ Exam Results Published!");
    } catch (e) {
      _showSnack("Error: $e");
    }
    setState(() => _isLoading = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildAdminCard(String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.secondary;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: colorScheme.primaryContainer,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard 🛠️"),
        actions: [
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildAdminCard("1. Generate Classes", Icons.school, _seedClasses),
                  _buildAdminCard("2. Generate Routes", Icons.directions_bus, _seedBusRoutes),
                  _buildAdminCard("3. Assign Class/Bus", Icons.link, _assignStudentsToClassesAndRoutes),
                  _buildAdminCard("4. Link Students to ME", Icons.person_pin, _linkStudentsToMe),
                  _buildAdminCard("5. Generate Schedules", Icons.calendar_month, _seedSchedules),
                  _buildAdminCard("6. Generate Homework", Icons.assignment, _seedAssignments),
                  _buildAdminCard("7. Publish Grades", Icons.score, _seedExamResults),
                  _buildAdminCard(
                    "Reset Attendance",
                    Icons.delete_forever,
                    () async {
                      var snap = await _firestore.collection('attendance').get();
                      for (var doc in snap.docs) await doc.reference.delete();
                      _showSnack("🗑️ Attendance Cleared!");
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            ),
    );
  }
}
