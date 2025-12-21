// lib/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications 🔔"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "Mark all as read",
            onPressed: () async {
              // تحديث كل الإشعارات لتصبح مقروءة
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
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('parent_uid', isEqualTo: uid)
            //.orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 80, color: Colors.grey),
                  Text(
                    "No notifications yet.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              bool isRead = data['is_read'] ?? false;

              // تنسيق الوقت
              String timeStr = "Just now";
              if (data['created_at'] != null) {
                DateTime dt = (data['created_at'] as Timestamp).toDate();
                timeStr = DateFormat('MMM d, h:mm a').format(dt);
              }

              return Card(
                color: isRead ? Colors.white : Colors.blue.shade50,
                // تمييز غير المقروء
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey : Colors.indigo,
                    child: Icon(
                      data['type'] == 'pickup'
                          ? Icons.directions_bus
                          : Icons.home,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    data['title'] ?? "Notification",
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(data['body'] ?? ""),
                      const SizedBox(height: 5),
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  onTap: () {
                    // عند الضغط، نحددها كمقروءة
                    if (!isRead) {
                      snapshot.data!.docs[index].reference.update({
                        'is_read': true,
                      });
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
