// lib/driver_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;
  List<Map<String, dynamic>> _students = [];
  String? _message;
  String driverName = "Loading...";
  bool _isTracking = false;
  Timer? _trackingTimer;
  final String _currentBusId = "bus_01";

  @override
  void initState() {
    super.initState();
    _getDriverName();
  }

  Future<void> _getDriverName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            driverName = doc.data()?['name'] ?? "Unknown Driver";
          });
        }
      } catch (e) {
        print("Error: $e");
      }
    }
  }

  void _toggleTrip() async {
    if (_isTracking) {
      _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    setState(() { _isTracking = true; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🚌 Trip Started!"), backgroundColor: Colors.green));

    FirebaseFirestore.instance.collection('buses').doc(_currentBusId).update({'is_active': true});

    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      Position position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance.collection('buses').doc(_currentBusId).update({
        'current_location': GeoPoint(position.latitude, position.longitude),
        'last_updated': FieldValue.serverTimestamp(),
        'plate_number': 'ABC-123',
      });
    });
  }

  void _stopTracking() {
    _trackingTimer?.cancel();
    setState(() { _isTracking = false; });
    FirebaseFirestore.instance.collection('buses').doc(_currentBusId).update({'is_active': false});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🛑 Trip Ended."), backgroundColor: Colors.red));
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo == null) return;

    setState(() {
      _selectedImage = photo;
      _isLoading = true;
      _message = null;
      _students = [];
    });

    try {
      final result = await ApiService.scanAttendance(_selectedImage!);
      if (result['success'] == true) {
        final basicStudents = result['students'];
        List<Map<String, dynamic>> enrichedStudents = [];
        if (basicStudents.isNotEmpty) {
          for (var student in basicStudents) {
            Map<String, dynamic> fullData = await _saveAndEnrichStudent(student);
            enrichedStudents.add(fullData);
          }
          setState(() {
            _students = enrichedStudents;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Students Boarded."), backgroundColor: Colors.green));
        } else {
          setState(() { _isLoading = false; _message = "No students recognized."; });
        }
      } else {
        setState(() { _isLoading = false; _message = result['error']; });
      }
    } catch (e) {
      setState(() { _isLoading = false; _message = "Error: $e"; });
    }
  }

  Future<Map<String, dynamic>> _saveAndEnrichStudent(Map<String, dynamic> apiStudent) async {
    String studentId = apiStudent['id'].toString();
    String parentPhone = "Unknown";
    String busId = "Unknown";
    String plateNumber = "Searching...";
    String grade = "N/A";

    try {
      final studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
      if (studentDoc.exists) {
        final data = studentDoc.data()!;
        parentPhone = data['parent_phone'] ?? "No Phone";
        busId = data['bus_id'] ?? "Unknown";
        grade = data['grade'] ?? "N/A";

        if (busId != "Unknown") {
          final busDoc = await FirebaseFirestore.instance.collection('buses').doc(busId).get();
          if (busDoc.exists) {
            plateNumber = busDoc.data()?['plate_number'] ?? "Unknown";
          }
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      Position? position;
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition();
      }

      final fullData = {
        // 👇👇👇 التعديل الجوهري هنا: حفظنا الآيدي كنص (بدون int.tryParse) 👇👇👇
        'student_id': studentId,

        'name': apiStudent['name'],
        'status': 'Boarded',
        'grade': grade,
        'parent_phone': parentPhone,
        'bus_plate': plateNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toString().split(' ')[0],
        'drop_off_time': null,
        'location': position != null ? GeoPoint(position.latitude, position.longitude) : null,
      };

      DocumentReference docRef = await FirebaseFirestore.instance.collection('attendance').add(fullData);
      fullData['doc_id'] = docRef.id;

      return fullData;
    } catch (e) {
      print("Error saving: $e");
      return apiStudent;
    }
  }

  Future<void> _markAsDroppedOff(String docId, int index) async {
    try {
      await FirebaseFirestore.instance.collection('attendance').doc(docId).update({
        'status': 'DroppedOff',
        'drop_off_time': FieldValue.serverTimestamp(),
      });
      setState(() { _students[index]['status'] = 'DroppedOff'; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dropped Off ✅")));
    } catch (e) {
      print("Error dropping off: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Driver Dashboard 🚌", style: TextStyle(fontSize: 18)),
            Text("Welcome, $driverName", style: const TextStyle(fontSize: 14)),
          ],
        ),
        backgroundColor: _isTracking ? Colors.red : Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _toggleTrip,
            icon: Icon(_isTracking ? Icons.stop_circle : Icons.play_circle_fill, color: Colors.white),
            label: Text(_isTracking ? "STOP TRIP" : "START TRIP", style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isTracking) Container(width: double.infinity, color: Colors.redAccent, padding: const EdgeInsets.all(8), child: const Text("📡 LIVE TRACKING ACTIVE", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity, margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
              child: _selectedImage != null ? ClipRRect(borderRadius: BorderRadius.circular(15), child: kIsWeb ? Image.network(_selectedImage!.path, fit: BoxFit.cover) : Image.file(File(_selectedImage!.path), fit: BoxFit.cover)) : const Center(child: Icon(Icons.camera_enhance, size: 60, color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: ElevatedButton.icon(onPressed: _isLoading ? null : () => _processImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text("Scan Face"))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _isLoading ? null : () => _processImage(ImageSource.gallery), icon: const Icon(Icons.photo), label: const Text("Gallery"))),
            ]),
          ),
          const Divider(height: 30),
          Expanded(
            flex: 3,
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                bool isBoarded = student['status'] == 'Boarded';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.shade50, Colors.white]), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 8, offset: const Offset(0, 4))]),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(children: [
                          CircleAvatar(radius: 30, backgroundColor: Colors.teal.shade100, child: Text(student['name'][0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal))),
                          const SizedBox(width: 15),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(student['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text("ID: ${student['student_id']}", style: TextStyle(color: Colors.grey[600]))]),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isBoarded ? Colors.green : Colors.grey, borderRadius: BorderRadius.circular(20)), child: Text(isBoarded ? "On Bus" : "Dropped Off", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ]),
                        const Divider(height: 15),
                        isBoarded ? ElevatedButton.icon(onPressed: () => _markAsDroppedOff(student['doc_id'], index), icon: const Icon(Icons.exit_to_app, color: Colors.white), label: const Text("DROP OFF", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent)) : const Text("Student left the bus", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}