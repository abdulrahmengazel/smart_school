import 'package:flutter/material.dart';

class AttendanceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String time;
  final String date;
  final VoidCallback? onTap; // دالة عند الضغط (للخريطة)

  const AttendanceCard({
    super.key,
    required this.data,
    required this.time,
    required this.date,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 👇 منطق الألوان والحالة تم عزله هنا
    String status = data['status'] ?? 'Absent';
    bool hasLocation = data['location'] != null;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (status == 'Present') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = "Arrived On Time";
    } else if (status == 'Late') {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
      statusText = "Arrived Late";
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = "Absent";
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap, // عند الضغط تنفذ الدالة القادمة من الأب
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // 1. أيقونة الحالة
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 30),
              ),
              const SizedBox(width: 15),

              // 2. تفاصيل النص
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: statusColor.withOpacity(0.8),
                          ),
                        ),
                        if (hasLocation)
                          const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Icon(Icons.location_on, color: Colors.red, size: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Bus: ${data['bus_plate'] ?? 'N/A'}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text(date,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12)),

                    if (hasLocation)
                      Text("Tap to track location 📍",
                          style: TextStyle(color: Colors.indigo[300], fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // 3. الوقت
              Column(
                children: [
                  Text(time,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
                  const Text("TIME", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}