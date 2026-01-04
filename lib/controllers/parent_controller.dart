import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as Intl;

/// المتحكم الخاص بشاشة الوالدين (ParentController)
/// يقوم بإدارة منطق البيانات والعمليات بعيداً عن الواجهة الرسومية
class ParentController extends ChangeNotifier {
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  DateTime _selectedDate = DateTime.now();

  // جلب معرف المستخدم الحالي وتاريخ العرض المختار
  String? get currentUserUid => _currentUserUid;
  DateTime get selectedDate => _selectedDate;

  /// وظيفة اختيار تاريخ لعرض حالة الطلاب في يوم محدد مع تطبيق سمة داكنة كاملة للتقويم
  Future<DateTime?> pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF778DA9), // لون الدائرة المختارة والعناوين
            onPrimary: Colors.white,
            surface: Color(0xFF1B263B), // خلفية رأس التقويم والجسم
            onSurface: Color(0xFFE0E1DD), // لون أرقام الأيام والنصوص
          ),
          dialogBackgroundColor: const Color(0xFF0D1B2A), // خلفية نافذة الحوار
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF778DA9), // لون أزرار الموافقة والإلغاء
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      _selectedDate = picked;
      notifyListeners(); 
      return picked;
    }
    return null;
  }

  /// وظيفة إرسال طلب غياب أو إجازة مرضية مع ثيم داكن أحمر للتنبيه
  Future<bool> requestAbsence(
    BuildContext context,
    String studentId,
    String studentName,
  ) async {
    // 1. اختيار تاريخ الغياب مع ثيم داكن محمر
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: "Select Absence Date 📅",
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.redAccent,
            onPrimary: Colors.white,
            surface: Color(0xFF1B263B),
            onSurface: Color(0xFFE0E1DD),
          ),
          dialogBackgroundColor: const Color(0xFF0D1B2A),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return false;

    String dateStr = pickedDate.toString().split(' ')[0];

    // 2. طلب تأكيد من المستخدم قبل الإرسال
    if (!context.mounted) return false;
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text("Confirm Absence", style: TextStyle(color: Colors.white)),
        content: Text("Mark $studentName as absent on $dateStr?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF778DA9))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    // 3. حفظ الطلب في Firestore
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
        return true;
      } catch (e) {
        log("Error requesting absence: $e");
        return false;
      }
    }
    return false;
  }

  /// تحويل التاريخ المختار إلى نص بصيغة YYYY-MM-DD
  String getFormattedDate() {
    return _selectedDate.toString().split(' ')[0];
  }

  /// التحقق مما إذا كان التاريخ المختار هو اليوم
  bool isToday() {
    String formattedDate = getFormattedDate();
    String todayDate = DateTime.now().toString().split(' ')[0];
    return formattedDate == todayDate;
  }

  /// معالجة بيانات الرحلة لتحديد اللون والنص المناسب للحالة
  Map<String, dynamic> getTripStatusDetails(Map<String, dynamic>? record) {
    String status = record?['status'] ?? 'Waiting';
    bool hasRecord = record != null;

    Color color;
    String statusText;
    bool hasTap;

    if (!hasRecord) {
      color = Colors.grey;
      statusText = "No record yet";
      hasTap = false;
    } else if (status == 'Boarded') {
      color = Colors.greenAccent;
      statusText = "On Bus (Live) 📍";
      hasTap = true;
    } else if (status == 'DroppedOff') {
      color = Colors.orangeAccent; 
      String time = "";
      if (record['drop_off_time'] != null) {
        final formatter = Intl.DateFormat('h:mm a');
        time = formatter.format((record['drop_off_time'] as Timestamp).toDate());
      }
      statusText = "Arrived ($time) ✅";
      hasTap = true;
    } else {
      color = Colors.amberAccent; 
      statusText = "Waiting...";
      hasTap = false;
    }

    return {
      'color': color,
      'statusText': statusText,
      'hasTap': hasTap,
    };
  }

  /// توزيع سجلات الحضور القادمة من Firestore
  void parseAttendanceRecords(
    QuerySnapshot attendanceSnapshot, {
    required Function(Map<String, dynamic>?) onMorning,
    required Function(Map<String, dynamic>?) onAfternoon,
  }) {
    Map<String, dynamic>? morningRecord;
    Map<String, dynamic>? afternoonRecord;

    if (attendanceSnapshot.docs.isNotEmpty) {
      var docs = attendanceSnapshot.docs;

      try {
        var morningDoc = docs.firstWhere(
          (d) => (d.data() as Map<String, dynamic>)['trip_type'] == 'pickup',
        );
        morningRecord = morningDoc.data() as Map<String, dynamic>;
      } catch (e) { }

      try {
        var afternoonDoc = docs.firstWhere(
          (d) => (d.data() as Map<String, dynamic>)['trip_type'] == 'dropoff',
        );
        afternoonRecord = afternoonDoc.data() as Map<String, dynamic>;
      } catch (e) { }
    }

    onMorning(morningRecord);
    onAfternoon(afternoonRecord);
  }

  /// جلب عدد التنبيهات غير المقروءة للوالد
  Stream<int> getUnreadNotificationsCount() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('parent_uid', isEqualTo: _currentUserUid)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// جلب قائمة الطلاب المرتبطين بحساب الوالد الحالي
  Stream<QuerySnapshot> getStudentsStream() {
    return FirebaseFirestore.instance
        .collection('students')
        .where('parent_uid', isEqualTo: _currentUserUid)
        .snapshots();
  }

  /// جلب سجلات حضور طالب محدد في تاريخ محدد
  Stream<QuerySnapshot> getAttendanceStream(String studentId, String dateStr) {
    return FirebaseFirestore.instance
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .where('date', isEqualTo: dateStr)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
