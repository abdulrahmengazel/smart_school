// lib/driver_screen.dart

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_school/services/api_service.dart';
import 'package:smart_school/services/auth_service.dart';
import 'package:smart_school/screens/login_screen.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;
  bool _isInitializing = true;

  List<Map<String, dynamic>> _students = [];

  String driverName = "Loading...";
  String? currentBusId;
  String? currentPlateNumber;
  String? currentRouteName;
  String? message;
  bool _isTracking = false;
  Timer? _trackingTimer;

  String _tripType = 'pickup';

  @override
  void initState() {
    super.initState();
    _initializeDriverAndBus();
  }

  Future<void> _initializeDriverAndBus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      var driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
      if (driverDoc.exists) {
        setState(() => driverName = driverDoc.data()?['name'] ?? "Unknown Driver");
      }
      var busQuery = await FirebaseFirestore.instance
          .collection('bus_routes')
          .where('driver_id', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (busQuery.docs.isNotEmpty) {
        var busData = busQuery.docs.first.data();
        setState(() {
          currentBusId = busQuery.docs.first.id;
          currentPlateNumber = busData['plate_number'];
          currentRouteName = busData['route_name'];
        });
      }
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _sendNotification(String parentUid, String title, String body, String type) async {
    if (parentUid.isEmpty || parentUid == 'Unknown') return;
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'parent_uid': parentUid,
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
      });
      log("🔔 Notification sent to $parentUid");
    } catch (e) {
      log("Error sending notification: $e");
    }
  }

  void _toggleTrip() async {
    if (currentBusId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ No bus assigned.")));
      return;
    }
    _isTracking ? _stopTracking() : await _startTracking();
  }

  Future<void> _startTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    setState(() => _isTracking = true);

    String typeText = _tripType == 'pickup' ? "☀️ Morning Trip (To School)" : "🌙 Afternoon Trip (To Home)";
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("🚀 Started: $typeText"), backgroundColor: Theme.of(context).colorScheme.tertiary),
    );

    await FirebaseFirestore.instance.collection('bus_routes').doc(currentBusId).update({
      'is_active': true,
      'current_trip_type': _tripType,
      'trip_start_time': FieldValue.serverTimestamp(),
    });

    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition();
        if (currentBusId != null) {
          await FirebaseFirestore.instance.collection('bus_routes').doc(currentBusId).update({
            'current_location': GeoPoint(position.latitude, position.longitude),
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        log("Error getting location: $e");
      }
    });
  }

  void _stopTracking() {
    _trackingTimer?.cancel();
    setState(() => _isTracking = false);
    if (currentBusId != null) {
      FirebaseFirestore.instance.collection('bus_routes').doc(currentBusId).update({'is_active': false});
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text("🛑 Trip Ended."), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _showAbsenteesDialog() async {
    String today = DateTime.now().toString().split(' ')[0];
    var snapshot = await FirebaseFirestore.instance.collection('leaves').where('date', isEqualTo: today).get();

    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🚫 Absent Students Today"),
        content: SizedBox(
          width: double.maxFinite,
          child: snapshot.docs.isEmpty
              ? const Text("No absences recorded for today. ✅")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.docs[index].data();
                    return ListTile(
                      leading: Icon(Icons.person_off, color: theme.colorScheme.error),
                      title: Text(data['student_name'] ?? 'Unknown'),
                      subtitle: Text("Reason: ${data['reason']}"),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  Future<void> _processImage(ImageSource source) async {
    if (currentBusId == null) return;
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo == null) return;

    setState(() {
      _selectedImage = photo;
      _isLoading = true;
      message = null;
      _students = [];
    });

    try {
      final result = await ApiService.scanAttendance(_selectedImage!);
      if (result['success'] == true) {
        final basicStudents = result['students'];
        List<Map<String, dynamic>> enrichedStudents = [];
        for (var student in basicStudents) {
          enrichedStudents.add(await _saveAndEnrichStudent(student));
        }
        setState(() => _students = enrichedStudents);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("✅ Students Boarded."), backgroundColor: Theme.of(context).colorScheme.tertiary),
        );
      } else {
        setState(() => message = result['error']);
      }
    } catch (e) {
      setState(() => message = "Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _saveAndEnrichStudent(Map<String, dynamic> apiStudent) async {
    String studentId = apiStudent['id'].toString();
    final studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
    final data = studentDoc.exists ? studentDoc.data()! : <String, dynamic>{};

    Position? position;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition();
      }
    } catch (e) {
      log("Error getting position: $e");
    }

    final fullData = {
      'student_id': studentId,
      'name': apiStudent['name'],
      'status': 'Boarded',
      'trip_type': _tripType,
      'grade': data['grade'] ?? 'N/A',
      'parent_phone': data['parent_phone'] ?? "No Phone",
      'parent_uid': data['parent_uid'] ?? "",
      'bus_id': currentBusId,
      'bus_plate': currentPlateNumber,
      'route_name': currentRouteName,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toString().split(' ')[0],
      'drop_off_time': null,
      'location': position != null ? GeoPoint(position.latitude, position.longitude) : null,
    };

    DocumentReference docRef = await FirebaseFirestore.instance.collection('attendance').add(fullData);
    fullData['doc_id'] = docRef.id;

    String msg = _tripType == 'pickup'
        ? "✅ ${apiStudent['name']} has boarded the bus to School."
        : "✅ ${apiStudent['name']} is on the bus returning Home.";
    _sendNotification(data['parent_uid'] ?? "", "Bus Status Update 🚌", msg, 'pickup');

    return fullData;
  }

  Future<void> _markAsDroppedOff(String docId, int index) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance.collection('attendance').doc(docId).update({
        'status': 'DroppedOff',
        'drop_off_time': FieldValue.serverTimestamp(),
        'drop_off_location': GeoPoint(position.latitude, position.longitude),
      });

      var studentData = _students[index];
      _sendNotification(
        studentData['parent_uid'] ?? "",
        "Arrived Safely 🏠",
        "${studentData['name']} has been dropped off safely.",
        'dropoff',
      );

      setState(() => _students[index]['status'] = 'DroppedOff');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dropped Off & Notified ✅")));
    } catch (e) {
      log("Error dropping off: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$driverName", style: const TextStyle(fontSize: 16)),
            Text(currentRouteName ?? 'No Route', style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: _isTracking ? colorScheme.error : colorScheme.primary,
        actions: [
          IconButton(icon: const Icon(Icons.person_off_outlined), tooltip: "Check Absentees", onPressed: _showAbsenteesDialog),
          if (currentBusId != null)
            TextButton.icon(
              onPressed: _toggleTrip,
              icon: Icon(_isTracking ? Icons.stop_circle : Icons.play_circle_fill),
              label: Text(_isTracking ? "STOP" : "START"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isTracking)
            Container(
              color: colorScheme.surfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Trip Type: ", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _tripType,
                    items: const [DropdownMenuItem(value: 'pickup', child: Text("To School")), DropdownMenuItem(value: 'dropoff', child: Text("To Home"))],
                    onChanged: (val) => setState(() => _tripType = val!),
                  ),
                ],
              ),
            ),
          if (_isTracking)
            Container(
              width: double.infinity,
              color: colorScheme.error,
              padding: const EdgeInsets.all(8),
              child: Text(
                "📡 LIVE TRACKING: ${_tripType == 'pickup' ? 'To School' : 'To Home'}",
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onError, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(15),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: kIsWeb
                          ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                          : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                    )
                  : Center(child: Icon(Icons.camera_enhance, size: 60, color: colorScheme.onSurfaceVariant.withOpacity(0.5))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || currentBusId == null) ? null : () => _processImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Scan Face"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isLoading || currentBusId == null) ? null : () => _processImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo),
                    label: const Text("Gallery"),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 30),
          Expanded(
            flex: 3,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      bool isBoarded = student['status'] == 'Boarded';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: colorScheme.primaryContainer,
                                    child: Text(
                                      student['name']?.isNotEmpty == true ? student['name'][0] : '?',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(student['name'], style: theme.textTheme.titleLarge),
                                        Text(
                                          _tripType == 'pickup' ? "To School 🏫" : "To Home 🏠",
                                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isBoarded) Icon(Icons.directions_bus, color: colorScheme.tertiary),
                                ],
                              ),
                              if (isBoarded) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _markAsDroppedOff(student['doc_id'], index),
                                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
                                    child: const Text("DROP OFF"),
                                  ),
                                ),
                              ],
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
