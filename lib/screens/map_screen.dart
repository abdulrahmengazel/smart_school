// lib/map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatelessWidget {
  final double startLat; // مكان الركوب
  final double startLng;
  final GeoPoint? dropOffLoc; // 👈 مكان النزول (قد يكون null إذا لم ينزل بعد)
  final String studentName;
  final String busId;

  const MapScreen({
    super.key,
    required this.startLat,
    required this.startLng,
    this.dropOffLoc, // 👈 اختياري
    required this.studentName,
    required this.busId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details 🗺️"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          // إذا نزل الطالب نركز الكاميرا على مكان النزول، وإلا على مكان الركوب
          initialCenter: dropOffLoc != null
              ? LatLng(dropOffLoc!.latitude, dropOffLoc!.longitude)
              : LatLng(startLat, startLng),
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.smart_school',
          ),

          // 1. نقطة الركوب (خضراء)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(startLat, startLng),
                width: 80,
                height: 80,
                child: const Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.green, size: 40),
                    Text(
                      "Start",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. نقطة النزول (حمراء) - تظهر فقط إذا توفرت البيانات
          if (dropOffLoc != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(dropOffLoc!.latitude, dropOffLoc!.longitude),
                  width: 80,
                  height: 80,
                  child: const Column(
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: 40),
                      Text(
                        "Drop Off",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // 3. الباص المتحرك (يظهر فقط إذا لم تنته الرحلة للطالب)
          if (dropOffLoc == null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bus_routes')
                  .doc(busId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists)
                  return const SizedBox();
                var data = snapshot.data!.data() as Map<String, dynamic>;
                GeoPoint? busLoc = data['current_location'];
                if (busLoc == null) return const SizedBox();

                return MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(busLoc.latitude, busLoc.longitude),
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(width: 2),
                        ),
                        child: const Icon(Icons.directions_bus, size: 30),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

