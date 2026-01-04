// lib/screens/map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// شاشة الخريطة: تعرض مسار الطالب الحي، نقطة الركوب، ونقطة النزول، مع تتبع موقع الحافلة
class MapScreen extends StatelessWidget {
  final double startLat; 
  final double startLng;
  final GeoPoint? dropOffLoc; 
  final String studentName;
  final String busId;

  const MapScreen({
    super.key,
    required this.startLat,
    required this.startLng,
    this.dropOffLoc,
    required this.studentName,
    required this.busId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("$studentName's Trip 🗺️"),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: FlutterMap(
        options: MapOptions(
          // تركيز الخريطة على مكان النزول إذا وصل الطالب، وإلا على مكان الركوب
          initialCenter: dropOffLoc != null
              ? LatLng(dropOffLoc!.latitude, dropOffLoc!.longitude)
              : LatLng(startLat, startLng),
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.smart_school',
            tileBuilder: (context, tileWidget, tile) {
              // جعل الخريطة داكنة لتناسب الهوية البصرية الجديدة
              return ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  -0.21, -0.72, -0.07, 0, 255,
                  -0.21, -0.72, -0.07, 0, 255,
                  -0.21, -0.72, -0.07, 0, 255,
                  0, 0, 0, 1, 0,
                ]),
                child: tileWidget,
              );
            },
          ),

          // 1. علامة نقطة الركوب (بداية الرحلة)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(startLat, startLng),
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    const Icon(Icons.location_on, color: Colors.greenAccent, size: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(5)),
                      child: const Text("Start", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. علامة نقطة النزول (نهاية الرحلة) - تظهر فقط عند وصول الطالب
          if (dropOffLoc != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(dropOffLoc!.latitude, dropOffLoc!.longitude),
                  width: 80,
                  height: 80,
                  child: Column(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(5)),
                        child: const Text("Arrived", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // 3. تتبع موقع الحافلة الحي (يختفي بمجرد نزول الطالب)
          if (dropOffLoc == null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('bus_routes').doc(busId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
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
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
                        ),
                        child: const Icon(Icons.directions_bus, size: 30, color: Colors.white),
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
