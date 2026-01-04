import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// المتحكم الخاص بلوحة تحكم المسؤول (AdminController)
/// يدير عمليات توليد البيانات التجريبية وربط الطلاب بالفصول والحافلات
class AdminController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// توليد فصول دراسية تجريبية
  Future<String> seedClasses() async {
    isLoading = true;
    try {
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
      return "✅ Classes Generated!";
    } catch (e) {
      return "❌ Error: $e";
    } finally {
      isLoading = false;
    }
  }

  /// توليد مسارات حافلات تجريبية
  Future<String> seedBusRoutes() async {
    isLoading = true;
    try {
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
      ];
      WriteBatch batch = _firestore.batch();
      for (var route in routes) {
        DocumentReference ref = _firestore.collection('bus_routes').doc();
        batch.set(ref, {...route, 'created_at': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      return "✅ Bus Routes Generated!";
    } catch (e) {
      return "❌ Error: $e";
    } finally {
      isLoading = false;
    }
  }

  /// توزيع الطلاب على الفصول والحافلات بشكل عشوائي/دوري
  Future<String> assignStudents() async {
    isLoading = true;
    try {
      var classesSnapshot = await _firestore.collection('classes').get();
      var routesSnapshot = await _firestore.collection('bus_routes').get();
      var studentsSnapshot = await _firestore.collection('students').get();

      if (classesSnapshot.docs.isEmpty || routesSnapshot.docs.isEmpty) {
        return "❌ No classes or routes found!";
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
      return "✅ Assigned ${studentsSnapshot.docs.length} students!";
    } catch (e) {
      return "❌ Error: $e";
    } finally {
      isLoading = false;
    }
  }

  /// ربط جميع الطلاب في النظام بحساب المستخدم الحالي (لأغراض التجربة كوالد)
  Future<String> linkStudentsToMe() async {
    isLoading = true;
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return "⚠️ Not logged in!";

      var students = await _firestore.collection('students').get();
      WriteBatch batch = _firestore.batch();
      for (var doc in students.docs) {
        batch.update(doc.reference, {'parent_uid': user.uid});
      }
      await batch.commit();
      return "✅ All students linked to YOU!";
    } catch (e) {
      return "❌ Error: $e";
    } finally {
      isLoading = false;
    }
  }

  /// توليد جداول دراسية تجريبية لكل الفصول
  Future<String> seedSchedules() async {
    isLoading = true;
    try {
      var classesSnapshot = await _firestore.collection('classes').get();
      if (classesSnapshot.docs.isEmpty) return "⚠️ No classes found.";

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
      return "✅ Class Schedules Generated!";
    } catch (e) {
      return "❌ Error: $e";
    } finally {
      isLoading = false;
    }
  }

  /// توليد واجبات مدرسية تجريبية
  Future<String> seedAssignments() async {
    isLoading = true;
    try {
      var classesSnapshot = await _firestore.collection('classes').get();
      if (classesSnapshot.docs.isEmpty) return "❌ No classes found!";

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
      return "✅ Assignments Generated!";
    } catch (e) {
      return "❌ Error: $e";
    } finally {
      isLoading = false;
    }
  }

  /// توليد نتائج امتحانات تجريبية
  Future<String> seedExamResults() async {
    isLoading = true;
    try {
      var studentsSnapshot = await _firestore.collection('students').get();
      if (studentsSnapshot.docs.isEmpty) return "❌ No students found!";

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
      return "✅ Exam Results Published!";
    } catch (e) {
      return "❌ Error: $e";
    } finally {
      isLoading = false;
    }
  }

  /// حذف جميع سجلات الحضور (لإعادة ضبط النظام)
  Future<String> clearAttendance() async {
    isLoading = true;
    try {
      var snap = await _firestore.collection('attendance').get();
      for (var doc in snap.docs) await doc.reference.delete();
      return "🗑️ Attendance Cleared!";
    } catch (e) {
      return "❌ Error: $e";
    } finally {
      isLoading = false;
    }
  }
}
