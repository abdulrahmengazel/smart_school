// lib/exam_results_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamResultsScreen extends StatelessWidget {
  final String studentId;
  final String studentName;

  const ExamResultsScreen({super.key, required this.studentId, required this.studentName});

  Map<String, dynamic> _getGradeInfo(int score, ColorScheme colorScheme) {
    if (score >= 90) return {'grade': 'A', 'color': colorScheme.tertiary, 'label': 'Excellent'};
    if (score >= 80) return {'grade': 'B', 'color': colorScheme.primary, 'label': 'Very Good'};
    if (score >= 70) return {'grade': 'C', 'color': colorScheme.secondary, 'label': 'Good'};
    if (score >= 60) return {'grade': 'D', 'color': colorScheme.secondary.withOpacity(0.7), 'label': 'Pass'};
    return {'grade': 'F', 'color': colorScheme.error, 'label': 'Fail'};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("$studentName's Grades 🎓"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('exam_results')
            .where('student_id', isEqualTo: studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.feed_outlined, size: 80, color: colorScheme.onSurface.withOpacity(0.5)),
                  Text("No grades published yet.", style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
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
              double percentage = maxScore > 0 ? score / maxScore : 0;
              var gradeInfo = _getGradeInfo(score, colorScheme);
              final Color gradeColor = gradeInfo['color'];

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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['subject'], style: theme.textTheme.titleLarge),
                                Text(data['exam_type'], style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: gradeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: gradeColor),
                            ),
                            child: Column(
                              children: [
                                Text(gradeInfo['grade'], style: theme.textTheme.headlineSmall?.copyWith(color: gradeColor, fontWeight: FontWeight.bold)),
                                Text("$score / $maxScore", style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 10,
                          backgroundColor: colorScheme.surfaceVariant,
                          color: gradeColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(gradeInfo['label'], style: theme.textTheme.labelMedium?.copyWith(color: gradeColor, fontWeight: FontWeight.bold)),
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
