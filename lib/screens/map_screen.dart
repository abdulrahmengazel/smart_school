// lib/map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details 🗺️"),
      ),
      body: FlutterMap(
        options: MapOptions(
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
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(startLat, startLng),
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    Icon(Icons.location_on, color: colorScheme.tertiary, size: 40),
                    Text(
                      "Start",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: colorScheme.onSurface,
                        backgroundColor: colorScheme.surface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dropOffLoc != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(dropOffLoc!.latitude, dropOffLoc!.longitude),
                  width: 80,
                  height: 80,
                  child: Column(
                    children: [
                      Icon(Icons.location_on, color: colorScheme.error, size: 40),
                      Text(
                        "Drop Off",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: colorScheme.onSurface,
                          backgroundColor: colorScheme.surface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (dropOffLoc == null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('bus_routes').doc(busId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                var data = snapshot.data!.data() as Map<String, dynamic>;
                GeoPoint? busLoc = data['current_location'];
                if (busLoc == null) return const SizedBox.shrink();

                return MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(busLoc.latitude, busLoc.longitude),
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(width: 2, color: colorScheme.onSecondary),
                        ),
                        child: Icon(Icons.directions_bus, size: 30, color: colorScheme.onSecondary),
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
