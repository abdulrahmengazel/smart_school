// lib/schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleScreen extends StatelessWidget {
  final String classId;
  final String className;

  const ScheduleScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<String> orderedDays = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("$className Schedule 📅"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('schedules').doc(classId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: colorScheme.onSurface.withOpacity(0.5)),
                  Text(
                    "No schedule published yet.",
                    style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          Map<String, dynamic> daysMap = data['days'] ?? {};

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orderedDays.length,
            itemBuilder: (context, index) {
              String dayName = orderedDays[index];
              List<dynamic> sessions = daysMap[dayName] ?? [];

              if (sessions.isEmpty) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dayName.substring(0, 3).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(dayName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text("${sessions.length} Classes"),
                  children: sessions.map((session) {
                    return ListTile(
                      leading: Icon(Icons.class_, color: colorScheme.secondary),
                      title: Text(session['subject'], style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text(session['time']),
                      trailing: Icon(Icons.arrow_forward_ios, size: 12, color: colorScheme.onSurface.withOpacity(0.5)),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
