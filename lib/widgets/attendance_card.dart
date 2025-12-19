import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceCard extends StatelessWidget {
  final String title;
  final String time;
  final String date;
  final String busPlate;
  final bool hasLocation;
  final Color statusColor;
  final IconData statusIcon;
  final VoidCallback? onTap;

  const AttendanceCard({
    super.key,
    required this.title,
    required this.time,
    required this.date,
    required this.busPlate,
    required this.hasLocation,
    required this.statusColor,
    required this.statusIcon,
    this.onTap,
  });

  factory AttendanceCard.fromData(Map<String, dynamic> data, {VoidCallback? onTap}) {
    String status = data['status'] ?? 'Absent';
    bool hasLocation = data['location'] != null;
    Timestamp? timestamp = data['timestamp'];

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

    return AttendanceCard(
      title: statusText,
      time: timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : "--:--",
      date: timestamp != null ? DateFormat('MMM dd, yyyy').format(timestamp.toDate()) : "Unknown",
      busPlate: data['bus_plate'] ?? 'N/A',
      hasLocation: hasLocation,
      statusColor: statusColor,
      statusIcon: statusIcon,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 30),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: statusColor.withAlpha(204),
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
                    Text("Bus: $busPlate",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text(date,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    if (hasLocation)
                      Text("Tap to track location 📍",
                          style: TextStyle(color: Colors.indigo[300], fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
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