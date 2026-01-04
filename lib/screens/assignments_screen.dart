// lib/screens/assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_school/controllers/academic_controller.dart';

/// شاشة الواجبات المدرسية: تعرض قائمة بالواجبات المطلوبة لكل صف مع إمكانية تحميل المرفقات
class AssignmentsScreen extends StatefulWidget {
  final String classId;
  final String className;

  const AssignmentsScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  late AcademicController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AcademicController();
  }

  /// وظيفة فتح روابط المرفقات (مثل ملفات PDF) في المتصفح الخارجي
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open attachment link")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.className} Assignments 📚"),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب الواجبات عبر المتحكم الأكاديمي
        stream: _controller.getAssignmentsStream(widget.classId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "No pending assignments! 🎉",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

              Timestamp? dueTs = data['due_date'];
              String dateStr = dueTs != null
                  ? DateFormat('EEE, MMM d').format(dueTs.toDate())
                  : "No Due Date";

              return Card(
                elevation: 0,
                color: Colors.indigo.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.indigo.withOpacity(0.1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // تصنيف المادة
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.indigo,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              data['subject'] ?? "General",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          // تاريخ التسليم
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                "Due: $dateStr",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        data['title'] ?? "No Title",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['description'] ?? "",
                        style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                      ),
                      const SizedBox(height: 20),

                      // زر تحميل المرفق إن وجد
                      if (data['attachment_url'] != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _launchURL(data['attachment_url']),
                            icon: const Icon(Icons.download),
                            label: const Text("Download Attachment (PDF)"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
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
