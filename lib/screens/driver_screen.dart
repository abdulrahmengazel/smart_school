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

  // نوع الرحلة (صباحي افتراضياً)
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
      var driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();
      if (driverDoc.exists) {
        setState(
          () => driverName = driverDoc.data()?['name'] ?? "Unknown Driver",
        );
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
          _isInitializing = false;
        });
      } else {
        setState(() {
          driverName = "$driverName (No Bus)";
          _isInitializing = false;
        });
      }
    } catch (e) {
      setState(() => _isInitializing = false);
    }
  }

  // --- دوال الإشعارات ---
  Future<void> _sendNotification(
    String parentUid,
    String title,
    String body,
    String type,
  ) async {
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

  // --- دوال التتبع ---
  void _toggleTrip() async {
    if (currentBusId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ No bus assigned.")));
      return;
    }
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

    setState(() => _isTracking = true);

    String typeText = _tripType == 'pickup'
        ? "☀️ Morning Trip (To School)"
        : "🌙 Afternoon Trip (To Home)";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🚀 Started: $typeText"),
        backgroundColor: Colors.green,
      ),
    );

    await FirebaseFirestore.instance
        .collection('bus_routes')
        .doc(currentBusId)
        .update({
          'is_active': true,
          'current_trip_type': _tripType,
          'trip_start_time': FieldValue.serverTimestamp(),
        });

    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      Position position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance
          .collection('bus_routes')
          .doc(currentBusId)
          .update({
            'current_location': GeoPoint(position.latitude, position.longitude),
            'last_updated': FieldValue.serverTimestamp(),
          });
    });
  }

  void _stopTracking() async {
    _trackingTimer?.cancel();
    setState(() => _isTracking = false);
    if (currentBusId != null) {
      await FirebaseFirestore.instance
          .collection('bus_routes')
          .doc(currentBusId)
          .update({'is_active': false});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🛑 Trip Ended."),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- دوال الغياب ---
  void _showAbsenteesDialog() async {
    String today = DateTime.now().toString().split(' ')[0];
    var snapshot = await FirebaseFirestore.instance
        .collection('leaves')
        .where('date', isEqualTo: today)
        .get();

    if (!mounted) return;

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
                      leading: const Icon(Icons.person_off, color: Colors.red),
                      title: Text(data['student_name'] ?? 'Unknown'),
                      subtitle: Text("Reason: ${data['reason']}"),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // --- معالجة الصور والحفظ ---
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
        if (basicStudents.isNotEmpty) {
          for (var student in basicStudents) {
            Map<String, dynamic> fullData = await _saveAndEnrichStudent(
              student,
            );
            enrichedStudents.add(fullData);
          }
          setState(() {
            _students = enrichedStudents;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Students Boarded."),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
            message = "No students recognized.";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          message = result['error'];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        message = "Error: $e";
      });
    }
  }

  Future<Map<String, dynamic>> _saveAndEnrichStudent(
    Map<String, dynamic> apiStudent,
  ) async {
    String studentId = apiStudent['id'].toString();
    String parentPhone = "Unknown";
    String parentUid = ""; // 👈 متغير جديد
    String grade = "N/A";

    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();
      if (studentDoc.exists) {
        final data = studentDoc.data()!;
        parentPhone = data['parent_phone'] ?? "No Phone";
        parentUid = data['parent_uid'] ?? ""; // 👈 جلب معرف الأب للإشعارات
        grade = data['grade'] ?? "N/A";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      Position? position;
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition();
      }

      final fullData = {
        'student_id': studentId,
        'name': apiStudent['name'],
        'status': 'Boarded',
        'trip_type': _tripType,
        'grade': grade,
        'parent_phone': parentPhone,
        'parent_uid': parentUid, // 👈 نحفظه محلياً لاستخدامه عند التنزيل
        'bus_id': currentBusId,
        'bus_plate': currentPlateNumber ?? "Unknown",
        'route_name': currentRouteName ?? "Unknown",
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toString().split(' ')[0],
        'drop_off_time': null,
        'location': position != null
            ? GeoPoint(position.latitude, position.longitude)
            : null,
      };

      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('attendance')
          .add(fullData);
      fullData['doc_id'] = docRef.id;

      // 🔔 إرسال إشعار الركوب
      String msg = _tripType == 'pickup'
          ? "✅ ${apiStudent['name']} has boarded the bus to School."
          : "✅ ${apiStudent['name']} is on the bus returning Home.";
      await _sendNotification(parentUid, "Bus Status Update 🚌", msg, 'pickup');

      return fullData;
    } catch (e) {
      log("Error saving: $e");
      return apiStudent;
    }
  }

  Future<void> _markAsDroppedOff(String docId, int index) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .update({
            'status': 'DroppedOff',
            'drop_off_time': FieldValue.serverTimestamp(),
            'drop_off_location': GeoPoint(
              position.latitude,
              position.longitude,
            ),
          });

      // 🔔 إرسال إشعار النزول
      // نجلب بيانات الطالب من القائمة المحلية لإرسال الإشعار
      var studentData = _students[index];
      String parentUid = studentData['parent_uid'] ?? "";
      String name = studentData['name'] ?? "Student";

      await _sendNotification(
        parentUid,
        "Arrived Safely 🏠",
        "$name has been dropped off safely.",
        'dropoff',
      );

      setState(() {
        _students[index]['status'] = 'DroppedOff';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Dropped Off & Notified ✅")));
    } catch (e) {
      log("Error dropping off: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Driver Dashboard 🚌", style: TextStyle(fontSize: 16)),
            Text(
              currentRouteName ?? 'No Route',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: _isTracking ? Colors.red : Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_off_outlined),
            tooltip: "Check Absentees",
            onPressed: _showAbsenteesDialog,
          ),
          if (currentBusId != null)
            TextButton.icon(
              onPressed: _toggleTrip,
              icon: Icon(
                _isTracking ? Icons.stop_circle : Icons.play_circle_fill,
                color: Colors.white,
              ),
              label: Text(
                _isTracking ? "STOP" : "START",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          // 👇 زر الخروج تمت إعادته
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isTracking)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Trip Type: ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _tripType,
                    items: const [
                      DropdownMenuItem(
                        value: 'pickup',
                        child: Text("To School"),
                      ),
                      DropdownMenuItem(
                        value: 'dropoff',
                        child: Text("To Home"),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _tripType = val!;
                      });
                    },
                  ),
                ],
              ),
            ),
          if (_isTracking)
            Container(
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.all(8),
              child: Text(
                "📡 LIVE TRACKING: ${_tripType == 'pickup' ? 'To School' : 'To Home'}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: kIsWeb
                          ? Image.network(
                              _selectedImage!.path,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                            ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.camera_enhance,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || currentBusId == null)
                        ? null
                        : () => _processImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Scan Face"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isLoading || currentBusId == null)
                        ? null
                        : () => _processImage(ImageSource.gallery),
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
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.teal.shade100,
                                  child: Text(
                                    student['name'][0],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _tripType == 'pickup'
                                          ? "To School 🏫"
                                          : "To Home 🏠",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (isBoarded)
                                  const Icon(
                                    Icons.directions_bus,
                                    color: Colors.green,
                                  ),
                              ],
                            ),
                            if (isBoarded) ...[
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () =>
                                    _markAsDroppedOff(student['doc_id'], index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  minimumSize: const Size(double.infinity, 40),
                                ),
                                child: const Text(
                                  "DROP OFF",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ],
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

