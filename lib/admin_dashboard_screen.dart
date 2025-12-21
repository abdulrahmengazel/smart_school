// lib/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  // --- 1. Infrastructure (Classes & Routes) ---

  Future<void> _seedClasses() async {
    setState(() => _isLoading = true);
    List<String> classes = [
      "Grade 10-A",
      "Grade 10-B",
      "Grade 11-A",
      "Grade 11-B",
      "Grade 12-A",
    ];
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
    String currentDriverId =
        FirebaseAuth.instance.currentUser?.uid ?? "unknown_driver";
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

  // --- 2. Students Management ---

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
      List<String> classNames = classesSnapshot.docs
          .map((e) => e['name'] as String)
          .toList();

      List<Map<String, dynamic>> routesData = routesSnapshot.docs
          .map(
            (doc) => {
              'id': doc.id,
              'name': doc['route_name'],
              'plate': doc['plate_number'],
            },
          )
          .toList();

      WriteBatch batch = _firestore.batch();
      int i = 0;

      for (var studentDoc in studentsSnapshot.docs) {
        // توزيع دوري
        int classIndex = i % classIds.length;
        int routeIndex = i % routesData.length;

        batch.update(studentDoc.reference, {
          'class_id': classIds[classIndex],
          'class_name': classNames[classIndex], // للتسهيل
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

  // --- 3. Academic (Schedules) ---

  Future<void> _seedSchedules() async {
    setState(() => _isLoading = true);

    try {
      // 1. جلب كل الصفوف
      var classesSnapshot = await _firestore.collection('classes').get();

      if (classesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ No classes found. Please generate classes first.",
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      WriteBatch batch = _firestore.batch();

      // أيام الأسبوع
      List<String> weekDays = [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
      ];

      // مواد دراسية عشوائية للتجربة
      List<String> subjects = [
        "Math",
        "Physics",
        "Chemistry",
        "English",
        "History",
        "Computer Science",
        "Biology",
      ];

      for (var classDoc in classesSnapshot.docs) {
        String classId = classDoc.id;
        String className = classDoc['name'];

        // بناء جدول عشوائي لهذا الصف
        Map<String, dynamic> daysSchedule = {};

        for (var day in weekDays) {
          // 3 حصص يومياً كمثال
          daysSchedule[day] = [
            {"subject": subjects[0], "time": "08:00 - 09:00"},
            {"subject": subjects[1], "time": "09:00 - 10:00"},
            {"subject": subjects[2], "time": "10:30 - 11:30"},
          ];
          // تدوير المواد لتغيير الجدول قليلاً
          subjects.shuffle();
        }

        // استخدام classId كمعرف للوثيقة لسهولة البحث لاحقاً
        DocumentReference ref = _firestore.collection('schedules').doc(classId);

        batch.set(ref, {
          'class_id': classId,
          'class_name': className,
          'days': daysSchedule,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Class Schedules Generated!")),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _isLoading = false);
  }

  // 6. توليد واجبات مدرسية (Assignments Seeding)
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
        // إنشاء 3 واجبات لكل صف
        for (int i = 1; i <= 3; i++) {
          DocumentReference ref = _firestore.collection('assignments').doc();

          // تاريخ التسليم: بعد i أيام من الآن
          DateTime dueDate = DateTime.now().add(Duration(days: i + 2));

          batch.set(ref, {
            'class_id': classDoc.id,
            'class_name': classDoc['name'],
            'subject': subjects[i % subjects.length],
            'title': 'Homework #$i: ${subjects[i % subjects.length]} Basics',
            'description':
                'Please solve page ${10 * i} to ${10 * i + 2} in your workbook.',
            'attachment_url':
                'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
            // رابط PDF تجريبي
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

  // Helper
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Widget Builder for Grid Cards
  Widget _buildAdminCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // 7. توليد نتائج الامتحانات (Exam Results Seeding)
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
      List<String> subjects = [
        "Math",
        "Physics",
        "Chemistry",
        "English",
        "Biology",
        "History",
      ];
      List<String> examTypes = ["Midterm Exam", "Final Exam"];

      for (var student in studentsSnapshot.docs) {
        // لكل طالب، ننشئ نتائج لكل المواد
        for (var subject in subjects) {
          // نختار عشوائياً نوع الامتحان (نصف فصلي أو نهائي)
          String type = examTypes[DateTime.now().millisecond % 2];

          // درجة عشوائية من 60 إلى 100
          int score = 60 + (DateTime.now().microsecond % 41);
          int maxScore = 100;

          DocumentReference ref = _firestore.collection('exam_results').doc();

          batch.set(ref, {
            'student_id': student.id,
            'student_name': student['name'],
            'subject': subject,
            'exam_type': type,
            'score': score,
            'max_score': maxScore,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard 🛠️"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2, // عمودين
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // 1. Infrastructure
                  _buildAdminCard(
                    "1. Generate Classes",
                    Icons.school,
                    Colors.indigo,
                    _seedClasses,
                  ),
                  _buildAdminCard(
                    "2. Generate Routes",
                    Icons.directions_bus,
                    Colors.orange,
                    _seedBusRoutes,
                  ),

                  // 2. Student Setup
                  _buildAdminCard(
                    "3. Assign Class/Bus",
                    Icons.link,
                    Colors.teal,
                    _assignStudentsToClassesAndRoutes,
                  ),
                  _buildAdminCard(
                    "4. Link Students to ME",
                    Icons.person_pin,
                    Colors.purple,
                    _linkStudentsToMe,
                  ),

                  // 3. Academic
                  _buildAdminCard(
                    "5. Generate Schedules",
                    Icons.calendar_month,
                    Colors.brown,
                    _seedSchedules,
                  ),
                  _buildAdminCard(
                    "6. Generate Homework",
                    Icons.assignment,
                    Colors.deepOrange,
                    _seedAssignments,
                  ),
                  _buildAdminCard(
                    "7. Publish Grades",
                    Icons.score,
                    Colors.green.shade700,
                    _seedExamResults,
                  ),

                  // 4. Reset (Dangerous!)
                  _buildAdminCard(
                    "Reset Attendance",
                    Icons.delete_forever,
                    Colors.red,
                    () async {
                      var snap = await _firestore
                          .collection('attendance')
                          .get();
                      for (var doc in snap.docs) await doc.reference.delete();
                      _showSnack("🗑️ Attendance Cleared!");
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
