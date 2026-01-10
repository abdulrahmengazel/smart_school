import 'dart:convert';
import 'dart:developer' show log;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // لمعرفة المنصة (kIsWeb)
import 'package:image_picker/image_picker.dart'; // <--- هذا السطر الناقص (import XFile)

class ApiService {
  static final String baseUrl =
      'https://walleyed-elda-sheaflike.ngrok-free.dev';
  static const String _attendanceEndpoint = '/scan-attendance';

  // نستخدم XFile هنا ليدعم الويب والموبايل
  static Future<Map<String, dynamic>> scanAttendance(XFile imageFile) async {
    final url = Uri.parse('$baseUrl$_attendanceEndpoint');

    try {
      var request = http.MultipartRequest('POST', url);

      if (kIsWeb) {
        // للويب: نرسل البايتات (Bytes)
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            await imageFile.readAsBytes(),
            filename: imageFile.name, // نستخدم الاسم الأصلي
          ),
        );
      } else {
        // للموبايل: نرسل المسار (Path)
        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );
      }

      log("🚀 Sending request to: $url");
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "success": false,
          "error": "Server Error: ${response.statusCode}",
        };
      }
    } catch (e) {
      return {"success": false, "error": "Connection Error: $e"};
    }
  }

  Future<Map<String, dynamic>?> getMyBus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // نبحث في جدول الباصات عن السطر الذي فيه driver_id هو نفس كود السائق الحالي
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('buses')
          .where('driver_id', isEqualTo: user.uid)
          .limit(1) // نريد باصاً واحداً فقط
          .get();

      if (query.docs.isNotEmpty) {
        // وجدنا الباص! نرجع بياناته
        var data = query.docs.first.data() as Map<String, dynamic>;
        // نضيف ID الوثيقة (bus_01) للمعلومات الراجعة لأننا سنحتاجه
        data['doc_id'] = query.docs.first.id;
        return data;
      }
    } catch (e) {
      log("Error fetching bus: $e");
    }
    return null; // لا يوجد باص
  }
}
