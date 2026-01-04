// lib/screens/exam_results_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_school/controllers/academic_controller.dart';

/// شاشة نتائج الامتحانات: تعرض درجات الطالب مع التقديرات الملونة
class ExamResultsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const ExamResultsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  late AcademicController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AcademicController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.studentName}'s Grades 🎓"),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب نتائج الامتحانات من المتحكم
        stream: _controller.getExamResultsStream(widget.studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.feed_outlined, size: 80, color: Colors.grey),
                  Text("No grades published yet.",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;

              int score = data['score'] ?? 0;
              int maxScore = data['max_score'] ?? 100;
              double percentage = score / maxScore;
              
              // الحصول على التقدير واللون بناءً على الدرجة من المتحكم
              var gradeInfo = _controller.getGradeInfo(score);

              return Card(
                elevation: 0,
                color: (gradeInfo['color'] as Color).withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: (gradeInfo['color'] as Color).withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['subject'],
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              Text(data['exam_type'],
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: (gradeInfo['color'] as Color),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: (gradeInfo['color'] as Color).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Column(
                              children: [
                                Text("${gradeInfo['grade']}",
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                Text("$score / $maxScore",
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // شريط التقدم الملون حسب التقدير
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 10,
                          backgroundColor: Colors.grey[200],
                          color: gradeInfo['color'],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${(percentage * 100).toInt()}%",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: gradeInfo['color'],
                              fontSize: 12,
                            ),
                          ),
                          Text(gradeInfo['label'],
                              style: TextStyle(
                                  color: gradeInfo['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
