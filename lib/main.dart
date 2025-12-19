import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'services/api_service.dart';
import 'parent_screen.dart'; // 👈 استيراد شاشة الأب

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SmartSchoolApp());
}

class SmartSchoolApp extends StatelessWidget {
  const SmartSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart School',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AttendanceScreen(),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;
  List<Map<String, dynamic>> _students = [];
  String? _message;

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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Attendance Saved & Synced!"), backgroundColor: Colors.green),
          );
        } else {
          setState(() {
            _isLoading = false;
            _message = "No students recognized.";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _message = result['error'];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = "Error: $e";
      });
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
        'student_id': int.tryParse(studentId),
        'name': apiStudent['name'],
        'status': apiStudent['status'],
        'grade': grade,
        'parent_phone': parentPhone,
        'bus_plate': plateNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toString().split(' ')[0],
        'location': position != null ? GeoPoint(position.latitude, position.longitude) : null,
      };

      await FirebaseFirestore.instance.collection('attendance').add(fullData);
      return fullData;

    } catch (e) {
      print("Error saving: $e");
      return apiStudent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Attendance 🎓"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // 👇 زر الانتقال لشاشة ولي الأمر
          IconButton(
            icon: const Icon(Icons.family_restroom),
            tooltip: "Parent View",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ParentScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
              child: _selectedImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: kIsWeb
                    ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                    : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
              )
                  : const Center(child: Icon(Icons.camera_enhance, size: 60, color: Colors.grey)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: _isLoading ? null : () => _processImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text("Scan Face"))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: _isLoading ? null : () => _processImage(ImageSource.gallery), icon: const Icon(Icons.photo), label: const Text("Gallery"))),
              ],
            ),
          ),
          const Divider(height: 30),

          Expanded(
            flex: 3,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _message != null
                ? Center(child: Text(_message!, style: const TextStyle(color: Colors.red, fontSize: 16)))
                : ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.teal.shade50, Colors.white]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.teal.shade100,
                              child: Text(student['name'][0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text("ID: ${student['student_id']} • Grade: ${student['grade']}", style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(student['status'], style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoChip(Icons.directions_bus, "${student['bus_plate']}", Colors.blue),
                            _infoChip(Icons.phone, "${student['parent_phone']}", Colors.orange),
                          ],
                        ),
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

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}