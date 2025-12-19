import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 ضروري للاتصال بقاعدة البيانات

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
        title: const Text("Live Tracking 🛰️"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          // نجعل المركز المبدئي هو مكان الطالب
          initialCenter: LatLng(latitude, longitude),
          initialZoom: 14.0,
        ),
        children: [
          // 1. طبقة الخريطة (OpenStreetMap)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.smart_school',
          ),

          // 2. طبقة الحافلة المتحركة (Live Bus Layer) 🚌
          StreamBuilder<DocumentSnapshot>(
            // 👇 هنا نستمع للباص الذي أنشأته (bus_01)
            stream: FirebaseFirestore.instance.collection('buses').doc('bus_01').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox(); // لا تظهر شيئاً إذا لم يكن هناك بيانات
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;
              bool isActive = data['is_active'] ?? false;
              GeoPoint? busLoc = data['current_location'];

              // إذا الرحلة غير نشطة أو لا يوجد موقع، لا تعرض الباص
              if (!isActive || busLoc == null) return const SizedBox();

              return MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(busLoc.latitude, busLoc.longitude),
                    width: 60,
                    height: 60,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue, // لون الباص
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                          ),
                          child: const Icon(Icons.directions_bus, color: Colors.white, size: 25),
                        ),
                        const SizedBox(height: 2),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            color: Colors.white.withOpacity(0.8),
                            child: const Text("Live Bus", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. طبقة الطالب (المكان الثابت الذي نزل فيه) 📍
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(latitude, longitude),
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(blurRadius: 4)],
                      ),
                      child: Text(
                        "$studentName (Drop-off)",
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