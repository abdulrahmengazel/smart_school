import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_school/services/api_service.dart';

/// DriverController: Manages bus tracking, face recognition, and student boarding/drop-off
class DriverController extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;
  bool _isInitializing = true;

  // List of current students on the bus
  List<Map<String, dynamic>> _students = [];

  String driverName = "Loading...";
  String? currentBusId;
  String? currentPlateNumber;
  String? currentRouteName;
  bool _isTracking = false;
  Timer? _trackingTimer;
  String _tripType = 'pickup';

  // Getters
  XFile? get selectedImage => _selectedImage;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  List<Map<String, dynamic>> get students => _students;
  bool get isTracking => _isTracking;
  String get tripType => _tripType;

  set tripType(String value) {
    _tripType = value;
    fetchCurrentBoardedStudents();
    notifyListeners();
  }

  /// Initialize driver and bus data, and load currently boarded passengers
  Future<void> initializeDriverAndBus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      var driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();
      if (driverDoc.exists) {
        driverName = driverDoc.data()?['name'] ?? "Unknown Driver";
      }
      var busQuery = await FirebaseFirestore.instance
          .collection('bus_routes')
          .where('driver_id', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (busQuery.docs.isNotEmpty) {
        var busData = busQuery.docs.first.data();
        currentBusId = busQuery.docs.first.id;
        currentPlateNumber = busData['plate_number'];
        currentRouteName = busData['route_name'];
        
        await fetchCurrentBoardedStudents();
      }
    } catch (e) {
      log("Error initializing: $e");
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Fetch students who are currently on the bus (Boarded status)
  Future<void> fetchCurrentBoardedStudents() async {
    if (currentBusId == null) return;
    String today = DateTime.now().toString().split(' ')[0];
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('bus_id', isEqualTo: currentBusId)
          .where('date', isEqualTo: today)
          .where('trip_type', isEqualTo: _tripType)
          .where('status', isEqualTo: 'Boarded')
          .get();

      _students = snapshot.docs.map((doc) {
        var data = doc.data();
        data['doc_id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    } catch (e) {
      log("Error fetching students: $e");
    }
  }

  /// Drop off all students currently on the bus
  Future<void> dropOffAll(Function(String) showMessage) async {
    if (_students.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    int count = 0;
    // Create a copy to iterate
    List<Map<String, dynamic>> toDropOff = List.from(_students);
    
    for (var student in toDropOff) {
      await markAsDroppedOff(student['doc_id'], -1, (msg) {});
      count++;
    }
    
    _students.clear();
    _isLoading = false;
    notifyListeners();
    showMessage("All $count students have been dropped off and removed from list.");
  }

  /// Mark student as dropped off and remove from local list
  Future<void> markAsDroppedOff(String docId, int index, Function(String) showMessage) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      
      // Find student data if index is not provided or valid
      Map<String, dynamic>? studentData;
      if (index >= 0 && index < _students.length) {
        studentData = _students[index];
      } else {
        studentData = _students.firstWhere((s) => s['doc_id'] == docId);
      }

      await FirebaseFirestore.instance.collection('attendance').doc(docId).update({
        'status': 'DroppedOff',
        'drop_off_time': FieldValue.serverTimestamp(),
        'drop_off_location': GeoPoint(position.latitude, position.longitude),
      });

      String parentUid = studentData['parent_uid'] ?? "";
      String name = studentData['name'] ?? "Student";

      await sendNotification(
        parentUid, 
        "Arrived Safely 🏠", 
        "$name has been dropped off safely.", 
        'dropoff'
      );

      // Remove from the list so they disappear from the UI
      _students.removeWhere((s) => s['doc_id'] == docId);
      notifyListeners();
      showMessage("$name dropped off and removed.");
    } catch (e) {
      log("Error dropping off: $e");
    }
  }

  /// Local clear of the students list view
  void clearStudentsList() {
    _students.clear();
    notifyListeners();
  }

  /// Get absentee students
  Future<List<Map<String, dynamic>>> getAbsentees() async {
    String today = DateTime.now().toString().split(' ')[0];
    var snapshot = await FirebaseFirestore.instance
        .collection('leaves')
        .where('date', isEqualTo: today)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Send notification to parent via Firestore
  Future<void> sendNotification(String parentUid, String title, String body, String type) async {
    if (parentUid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'parent_uid': parentUid,
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log("Error sending notification: $e");
    }
  }

  /// Start/Stop Trip Tracking
  Future<void> toggleTrip(Function(String, {bool isError}) showMessage) async {
    if (currentBusId == null) {
      showMessage("❌ No bus assigned.", isError: true);
      return;
    }
    if (_isTracking) await stopTracking(showMessage);
    else await startTracking(showMessage);
  }

  Future<void> startTracking(Function(String, {bool isError}) showMessage) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _isTracking = true;
    notifyListeners();
    showMessage("🚀 Trip Started: Location tracking active.");

    await FirebaseFirestore.instance.collection('bus_routes').doc(currentBusId).update({
      'is_active': true,
      'current_trip_type': _tripType,
      'trip_start_time': FieldValue.serverTimestamp(),
    });

    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      Position position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance.collection('bus_routes').doc(currentBusId).update({
        'current_location': GeoPoint(position.latitude, position.longitude),
        'last_updated': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> stopTracking(Function(String, {bool isError}) showMessage) async {
    _trackingTimer?.cancel();
    _isTracking = false;
    notifyListeners();
    if (currentBusId != null) {
      await FirebaseFirestore.instance.collection('bus_routes').doc(currentBusId).update({'is_active': false});
    }
    showMessage("🛑 Trip Ended.", isError: true);
  }

  /// Process student image using AI scan
  Future<void> processImage(ImageSource source, Function(String, {bool isError}) showMessage) async {
    if (currentBusId == null) return;
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo == null) return;

    _selectedImage = photo;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.scanAttendance(_selectedImage!);
      if (result['success'] == true) {
        final basicStudents = result['students'];
        if (basicStudents != null && basicStudents.isNotEmpty) {
          for (var student in basicStudents) {
            bool exists = _students.any((s) => s['student_id'] == student['id'].toString());
            if (!exists) {
              Map<String, dynamic> fullData = await _saveAndEnrichStudent(student);
              _students.add(fullData);
            }
          }
          showMessage("✅ Students boarded.");
        } else showMessage("⚠️ No students recognized.", isError: true);
      } else showMessage("❌ AI Server Error.", isError: true);
    } catch (e) {
      showMessage("❌ Processing error: $e", isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _saveAndEnrichStudent(Map<String, dynamic> apiStudent) async {
    String studentId = apiStudent['id'].toString();
    String parentUid = "";
    String grade = "N/A";

    try {
      final studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
      if (studentDoc.exists) {
        parentUid = studentDoc.data()?['parent_uid'] ?? "";
        grade = studentDoc.data()?['grade'] ?? "N/A";
      }

      Position position = await Geolocator.getCurrentPosition();

      final fullData = {
        'student_id': studentId,
        'name': apiStudent['name'],
        'status': 'Boarded',
        'trip_type': _tripType,
        'grade': grade,
        'parent_uid': parentUid,
        'bus_id': currentBusId,
        'bus_plate': currentPlateNumber ?? "Unknown",
        'route_name': currentRouteName ?? "Unknown",
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toString().split(' ')[0],
        'location': GeoPoint(position.latitude, position.longitude),
      };

      DocumentReference docRef = await FirebaseFirestore.instance.collection('attendance').add(fullData);
      fullData['doc_id'] = docRef.id;

      String msg = _tripType == 'pickup'
          ? "✅ ${apiStudent['name']} is on the bus heading to school."
          : "✅ ${apiStudent['name']} is on the bus heading home.";
      await sendNotification(parentUid, "Bus Update", msg, 'pickup');

      return fullData;
    } catch (e) {
      log("Error saving: $e");
      return apiStudent;
    }
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }
}
