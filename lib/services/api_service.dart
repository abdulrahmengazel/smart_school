import 'dart:convert';
// import 'dart:io'; // نحذفه أو نتركه، لكن XFile يغنينا عنه في الويب
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // لمعرفة المنصة (kIsWeb)
import 'package:image_picker/image_picker.dart'; // <--- هذا السطر الناقص (import XFile)

class ApiService {

  static final String baseUrl = 'http://127.0.0.1:8000';

  static const String _attendanceEndpoint = '/api/attendance/scan';

  // نستخدم XFile هنا ليدعم الويب والموبايل
  static Future<Map<String, dynamic>> scanAttendance(XFile imageFile) async {
    final url = Uri.parse('${baseUrl}$_attendanceEndpoint');

    try {
      var request = http.MultipartRequest('POST', url);

      if (kIsWeb) {
        // للويب: نرسل البايتات (Bytes)
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          await imageFile.readAsBytes(),
          filename: imageFile.name, // نستخدم الاسم الأصلي
        ));
      } else {
        // للموبايل: نرسل المسار (Path)
        request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      }

      print("🚀 Sending request to: $url");
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "error": "Server Error: ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "error": "Connection Error: $e"};
    }
  }
}