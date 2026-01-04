// lib/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// شاشة التنبيهات: تعرض جميع الإشعارات المرسلة للوالد (مثل صعود/نزول الطلاب)
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Notifications 🔔", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        actions: [
          // زر لتحديد جميع الإشعارات كمقروءة دفعة واحدة
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "Mark all as read",
            onPressed: () async {
              var batch = FirebaseFirestore.instance.batch();
              var snaps = await FirebaseFirestore.instance
                  .collection('notifications')
                  .where('parent_uid', isEqualTo: uid)
                  .where('is_read', isEqualTo: false)
                  .get();

              for (var doc in snaps.docs) {
                batch.update(doc.reference, {'is_read': true});
              }
              await batch.commit();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب الإشعارات الخاصة بالوالد الحالي مرتبة من الأحدث للأقدم
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('parent_uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: colorScheme.onSurface.withOpacity(0.3)),
                  const SizedBox(height: 10),
                  Text("No notifications yet.", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            );
          }

          // ترتيب الإشعارات يدوياً لتجنب الحاجة لفهرس (Index) في Firebase حالياً
          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            var aTime = (a.data() as Map)['created_at'] as Timestamp?;
            var bTime = (b.data() as Map)['created_at'] as Timestamp?;
            return (bTime?.seconds ?? 0).compareTo(aTime?.seconds ?? 0);
          });

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isRead = data['is_read'] ?? false;

              // تنسيق وقت وصول الإشعار
              String timeStr = "Just now";
              if (data['created_at'] != null) {
                DateTime dt = (data['created_at'] as Timestamp).toDate();
                timeStr = DateFormat('MMM d, h:mm a').format(dt);
              }

              return Card(
                elevation: 0,
                color: isRead ? colorScheme.primaryContainer.withOpacity(0.3) : Colors.amber.withOpacity(0.15),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: isRead ? colorScheme.onSurface.withOpacity(0.1) : Colors.amber.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? colorScheme.secondary.withOpacity(0.2) : Colors.amber,
                    child: Icon(
                      data['type'] == 'pickup' ? Icons.directions_bus : Icons.home,
                      color: isRead ? colorScheme.onSurface.withOpacity(0.7) : Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    data['title'] ?? "Notification",
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        data['body'] ?? "",
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 6),
                      Text(timeStr, style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.5))),
                    ],
                  ),
                  onTap: () {
                    // عند النقر على الإشعار، يتم تحديث حالته لمقروء
                    if (!isRead) {
                      docs[index].reference.update({'is_read': true});
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
