import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // تسجيل الدخول
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      return result.user;
    } catch (e) {
      print("Error signing in: $e");
      return null;
    }
  }

  // معرفة دور المستخدم (سائق أم أب)
  Future<String> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc['role'] ?? 'parent';
      }
    } catch (e) {
      print("Error getting role: $e");
    }
    return 'parent'; // قيمة افتراضية
  }

  // الخروج
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // معرفة المستخدم الحالي
  User? get currentUser => _auth.currentUser;
}