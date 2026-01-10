import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceCard extends StatelessWidget {
  final String time;
  final String date;
  final String busPlate;
  final bool hasLocation;
  final VoidCallback? onTap;
  final String status;

  const AttendanceCard({
    super.key,
    required this.time,
    required this.date,
    required this.busPlate,
    required this.hasLocation,
    required this.status,
    this.onTap,
  });

  factory AttendanceCard.fromData(Map<String, dynamic> data, {VoidCallback? onTap}) {
    Timestamp? timestamp = data['timestamp'];

    return AttendanceCard(
      status: data['status'] ?? 'Absent',
      time: timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : "--:--",
      date: timestamp != null ? DateFormat('MMM dd, yyyy').format(timestamp.toDate()) : "Unknown",
      busPlate: data['bus_plate'] ?? 'N/A',
      hasLocation: data['location'] != null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (status) {
      case 'Present':
        statusColor = colorScheme.tertiary;
        statusIcon = Icons.check_circle;
        statusText = "Arrived On Time";
        break;
      case 'Late':
        statusColor = colorScheme.secondary;
        statusIcon = Icons.warning_amber_rounded;
        statusText = "Arrived Late";
        break;
      default: // 'Absent'
        statusColor = colorScheme.error;
        statusIcon = Icons.cancel;
        statusText = "Absent";
        break;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
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
                          statusText,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        if (hasLocation)
                          Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Icon(Icons.location_on, color: colorScheme.error, size: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Bus: $busPlate",
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                    Text(date,
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.5))),
                    if (hasLocation)
                      Text("Tap to track location 📍",
                          style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(time,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  Text("TIME", style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
