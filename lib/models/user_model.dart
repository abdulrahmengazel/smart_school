class UserModel {
  final String uid;
  final String email;
  final String role; // 'driver' or 'parent'

  UserModel({required this.uid, required this.email, required this.role});

  // تحويل البيانات القادمة من Firestore إلى كلاس
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'parent', // الافتراضي ولي أمر
    );
  }

  // تحويل الكلاس إلى بيانات لرفعها لـ Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
    };
  }
}