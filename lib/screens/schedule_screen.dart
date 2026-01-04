// lib/screens/schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_school/controllers/academic_controller.dart';

/// شاشة الجدول الدراسي: تعرض الحصص اليومية مقسمة حسب أيام الأسبوع
class ScheduleScreen extends StatefulWidget {
  final String classId;
  final String className;

  const ScheduleScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late AcademicController _controller;

  // خريطة ألوان مخصصة لكل يوم من أيام الأسبوع لإضفاء مظهر حيوي
  final Map<String, Color> _dayColors = {
    'Sunday': Colors.indigoAccent,
    'Monday': Colors.tealAccent,
    'Tuesday': Colors.orangeAccent,
    'Wednesday': Colors.purpleAccent,
    'Thursday': Colors.greenAccent,
  };

  @override
  void initState() {
    super.initState();
    _controller = AcademicController();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text("${widget.className} Schedule 📅"),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // جلب بيانات الجدول عبر المتحكم
        stream: _controller.getScheduleStream(widget.classId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: colorScheme.onSurface.withOpacity(0.3)),
                  Text(
                    "No schedule published yet.",
                    style: TextStyle(fontSize: 18, color: colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          Map<String, dynamic> daysMap = data['days'] ?? {};

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _controller.orderedDays.length,
            itemBuilder: (context, index) {
              String dayName = _controller.orderedDays[index];
              List<dynamic> sessions = daysMap[dayName] ?? [];

              if (sessions.isEmpty) return const SizedBox();

              // الحصول على اللون المخصص لليوم أو استخدام اللون الافتراضي
              Color dayColor = _dayColors[dayName] ?? colorScheme.primary;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: colorScheme.primaryContainer.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: dayColor.withOpacity(0.3), width: 1),
                ),
                child: ExpansionTile(
                  collapsedIconColor: dayColor,
                  iconColor: dayColor,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: dayColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dayName.substring(0, 3).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: dayColor,
                      ),
                    ),
                  ),
                  title: Text(
                    dayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    "${sessions.length} Classes",
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  children: sessions.map((session) {
                    return ListTile(
                      leading: Icon(Icons.class_outlined, color: dayColor.withOpacity(0.7)),
                      title: Text(
                        session['subject'],
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      subtitle: Text(
                        session['time'],
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                      ),
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
