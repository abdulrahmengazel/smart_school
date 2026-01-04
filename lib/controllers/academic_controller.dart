import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// المتحكم الأكاديمي (AcademicController)
/// يدير منطق البيانات للجداول والنتائج والواجبات
class AcademicController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// جلب تيار (Stream) لجدول حصص صف معين
  Stream<DocumentSnapshot> getScheduleStream(String classId) {
    return _firestore.collection('schedules').doc(classId).snapshots();
  }

  /// جلب تيار (Stream) لنتائج امتحانات طالب معين
  Stream<QuerySnapshot> getExamResultsStream(String studentId) {
    return _firestore.collection('exam_results')
        .where('student_id', isEqualTo: studentId)
        .snapshots();
  }

  /// جلب تيار (Stream) للواجبات المدرسية لصف معين
  Stream<QuerySnapshot> getAssignmentsStream(String classId) {
    // تم تعديل الاستعلام ليكون أبسط لتجنب الحاجة لفهرس (Index) حالياً
    return _firestore.collection('assignments')
        .where('class_id', isEqualTo: classId)
        .snapshots();
  }

  /// منطق تحديد التقدير واللون بناءً على الدرجة
  Map<String, dynamic> getGradeInfo(int score) {
    if (score >= 90) {
      return {'grade': 'A', 'color': Colors.green, 'label': 'Excellent'};
    } else if (score >= 80) {
      return {'grade': 'B', 'color': Colors.blue, 'label': 'Very Good'};
    } else if (score >= 70) {
      return {'grade': 'C', 'color': Colors.orange, 'label': 'Good'};
    } else if (score >= 60) {
      return {'grade': 'D', 'color': Colors.amber, 'label': 'Pass'};
    } else {
      return {'grade': 'F', 'color': Colors.red, 'label': 'Fail'};
    }
  }

  /// ترتيب أيام الأسبوع بشكل صحيح للعرض
  List<String> get orderedDays => [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
  ];
}
