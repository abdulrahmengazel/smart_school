import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'map_screen.dart';
import 'widgets/attendance_card.dart'; // 👈 استدعاء الملف الجديد

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final TextEditingController _idController = TextEditingController(text: "21");
  int? _targetId = 21;

  void _openMap(BuildContext context, double lat, double lng, String name, String time) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          latitude: lat,
          longitude: lng,
          studentName: name,
          time: time,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parent Dashboard 👨‍👩‍👦"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // شريط البحث
          _buildSearchBar(),

          // القائمة
          Expanded(
            child: _targetId == null
                ? const Center(child: Text("Please enter a valid Student ID"))
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where('student_id', isEqualTo: _targetId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No records found."));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

                    // تحضير البيانات
                    Timestamp? timestamp = data['timestamp'];
                    String timeStr = timestamp != null
                        ? DateFormat('hh:mm a').format(timestamp.toDate())
                        : "--:--";
                    String dateStr = timestamp != null
                        ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                        : "Unknown";
                    GeoPoint? loc = data['location'];

                    // 👇 استدعاء الودجت النظيف الذي أنشأناه
                    return AttendanceCard(
                      data: data,
                      time: timeStr,
                      date: dateStr,
                      onTap: loc != null
                          ? () => _openMap(context, loc.latitude, loc.longitude, data['name'], timeStr)
                          : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No GPS data 🚫"))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // فصلنا كود البحث في دالة صغيرة لترتيب الكود أكثر
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.indigo.withOpacity(0.05),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Student ID",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => setState(() => _targetId = int.tryParse(_idController.text)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
            child: const Text("Track"),
          ),
        ],
      ),
    );
  }
}