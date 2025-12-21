// lib/exam_results_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamResultsScreen extends StatelessWidget {
  final String studentId;
  final String studentName;

  const ExamResultsScreen({super.key, required this.studentId, required this.studentName});

  // دالة مساعدة لتحديد اللون والتقدير حسب الدرجة
  Map<String, dynamic> _getGradeInfo(int score) {
    if (score >= 90) return {'grade': 'A', 'color': Colors.green, 'label': 'Excellent'};
    if (score >= 80) return {'grade': 'B', 'color': Colors.blue, 'label': 'Very Good'};
    if (score >= 70) return {'grade': 'C', 'color': Colors.orange, 'label': 'Good'};
    if (score >= 60) return {'grade': 'D', 'color': Colors.amber, 'label': 'Pass'};
    return {'grade': 'F', 'color': Colors.red, 'label': 'Fail'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$studentName's Grades 🎓"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('exam_results')
            .where('student_id', isEqualTo: studentId)
        // .orderBy('subject') // قد يحتاج لفهرس، اتركه معلقاً الآن
            .snapshots(),
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
                  Text("No grades published yet.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

              int score = data['score'] ?? 0;
              int maxScore = data['max_score'] ?? 100;
              double percentage = score / maxScore;
              var gradeInfo = _getGradeInfo(score);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                              Text(data['subject'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(data['exam_type'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: gradeInfo['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: gradeInfo['color']),
                            ),
                            child: Column(
                              children: [
                                Text("${gradeInfo['grade']}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: gradeInfo['color'])),
                                Text("$score / $maxScore", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // شريط التقدم
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 10,
                          backgroundColor: Colors.grey[200],
                          color: gradeInfo['color'],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(gradeInfo['label'], style: TextStyle(color: gradeInfo['color'], fontWeight: FontWeight.bold, fontSize: 12)),
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