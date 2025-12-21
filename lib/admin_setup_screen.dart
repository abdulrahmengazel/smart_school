// lib/admin_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  // 1. Seeding Classes (English)
  Future<void> _seedClasses() async {
    setState(() => _isLoading = true);

    // قائمة الصفوف باللغة الإنجليزية
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

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Classes (English) Added Successfully!"),
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
    }

    setState(() => _isLoading = false);
  }

  // 2. Seeding Bus Routes (English)
  Future<void> _seedBusRoutes() async {
    setState(() => _isLoading = true);

    // نستخدم الـ UID الحالي للسائق لغرض التجربة، لكي يظهر الباص في حسابك
    String currentDriverId =
        FirebaseAuth.instance.currentUser?.uid ?? "unknown_driver";

    List<Map<String, dynamic>> routes = [
      {
        'route_name': 'North Route (City Center)',
        'plate_number': 'ABC-123',
        'driver_id': currentDriverId, // مربوط بحسابك الحالي
        'capacity': 25,
      },
      {
        'route_name': 'South Route (Flower District)',
        'plate_number': 'XYZ-999',
        'driver_id': 'driver_02_uid', // سائق وهمي آخر
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

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Bus Routes (English) Added Successfully!"),
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
    }

    setState(() => _isLoading = false);
  }

  // 3. دالة ربط الطلاب بالصفوف والخطوط (Assign Students)
  // 3. دالة ترقية ملفات الطلاب (Profile Upgrade)
  Future<void> _upgradeStudentProfiles() async {
    setState(() => _isLoading = true);

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ You must be logged in to assign Parent UID")));
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. جلب البيانات اللازمة
      var studentsSnapshot = await _firestore.collection('students').get();
      var classesSnapshot = await _firestore.collection('classes').get();
      var routesSnapshot = await _firestore.collection('bus_routes').get();

      if (studentsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No students found to upgrade!")));
        setState(() => _isLoading = false);
        return;
      }

      // تجهيز قوائم IDs للتوزيع العشوائي
      List<String> classIds = classesSnapshot.docs.map((e) => e.id).toList();
      List<String> busIds = routesSnapshot.docs.map((e) => e.id).toList();

      WriteBatch batch = _firestore.batch();
      int i = 0;

      for (var studentDoc in studentsSnapshot.docs) {
        // توزيع الطلاب على الصفوف والباصات بالتناوب
        String assignedClassId = classIds.isNotEmpty ? classIds[i % classIds.length] : 'unknown_class';
        String assignedBusId = busIds.isNotEmpty ? busIds[i % busIds.length] : 'unknown_bus';

        batch.update(studentDoc.reference, {
          // الحقول الجديدة المطلوبة
          'class_id': assignedClassId,
          'bus_id': assignedBusId,

          // ربط الطالب بحسابك الحالي لتتمكن من رؤيته في شاشة الأهل
          'parent_uid': currentUser.uid,

          // رقم هاتف افتراضي
          'parent_phone_1': '0501234567',

          // حقول إضافية مفيدة للعرض السريع (Optional but recommended)
          'updated_at': FieldValue.serverTimestamp(),
        });
        i++;
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Upgraded ${studentsSnapshot.docs.length} students & Linked to YOU!")));
      }

    } catch (e) {
      print("Error upgrading: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Setup 🛠️")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Initialize System Data",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Click buttons once to seed data",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Generate Classes Button
                  ElevatedButton.icon(
                    onPressed: _seedClasses,
                    icon: const Icon(Icons.school),
                    label: const Text("Generate Classes (Grade 10-A...)"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(280, 50),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Generate Bus Routes Button
                  ElevatedButton.icon(
                    onPressed: _seedBusRoutes,
                    icon: const Icon(Icons.directions_bus),
                    label: const Text("Generate Bus Routes"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(280, 50),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // زر الربط السحري
                  const SizedBox(height: 20),

// زر الترقية والربط
                  ElevatedButton.icon(
                    onPressed: _upgradeStudentProfiles,
                    icon: const Icon(Icons.upgrade),
                    label: const Text("Upgrade Profiles & Link to ME"), // Link to Me تعني ربطهم بحسابك الحالي
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(280, 50),
                        backgroundColor: Colors.purple, // لون مميز للترقية
                        foregroundColor: Colors.white
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
