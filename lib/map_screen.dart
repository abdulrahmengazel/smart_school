import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // مكتبة الخريطة
import 'package:latlong2/latlong.dart'; // مكتبة الإحداثيات

class MapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String studentName;
  final String time;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.studentName,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tracking Location 📍"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(latitude, longitude), // مركز الخريطة
          initialZoom: 15.0, // مستوى التقريب (Zoom)
        ),
        children: [
          // 1. طبقة الخريطة (OpenStreetMap)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.smart_school',
          ),

          // 2. طبقة الدبوس (Marker)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(latitude, longitude),
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(blurRadius: 4)],
                      ),
                      child: Text(
                        studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}