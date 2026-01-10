// lib/screens/assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_school/controllers/academic_controller.dart';

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

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open attachment link")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.className} Assignments 📚"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.getAssignmentsStream(widget.classId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in, size: 80, color: colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  Text(
                    "No pending assignments! 🎉",
                    style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
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
              String dateStr = dueTs != null ? DateFormat('EEE, MMM d').format(dueTs.toDate()) : "No Due Date";

              return Card(
                elevation: 0,
                color: colorScheme.primaryContainer.withOpacity(0.3),
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: colorScheme.primaryContainer),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              data['subject'] ?? "General",
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: colorScheme.error),
                              const SizedBox(width: 4),
                              Text(
                                "Due: $dateStr",
                                style: TextStyle(
                                  color: colorScheme.error,
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
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['description'] ?? "",
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, color: colorScheme.onSurface.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 20),
                      if (data['attachment_url'] != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _launchURL(data['attachment_url']),
                            icon: const Icon(Icons.download),
                            label: const Text("Download Attachment (PDF)"),
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
