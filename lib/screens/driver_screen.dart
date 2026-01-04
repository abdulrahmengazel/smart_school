// lib/screens/driver_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_school/services/auth_service.dart';
import 'package:smart_school/screens/login_screen.dart';
import 'package:smart_school/controllers/driver_controller.dart';

/// Driver Dashboard Screen: Unified design with dark navy theme
class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  late DriverController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DriverController();
    _controller.initializeDriverAndBus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(colorScheme),
          body: Column(
            children: [
              _buildTripStatus(colorScheme),
              _buildImagePreview(colorScheme),
              _buildActionButtons(colorScheme),
              _buildListHeader(colorScheme),
              _buildStudentList(colorScheme),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(ColorScheme colorScheme) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Driver Hub 🚌", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            _controller.currentRouteName ?? "Offline",
            style: TextStyle(fontSize: 12, color: colorScheme.secondary),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_search_outlined),
          onPressed: _showAbsentees,
          tooltip: "Absentees",
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await AuthService().signOut();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildTripStatus(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _controller.isTracking ? Icons.online_prediction : Icons.offline_bolt,
                color: _controller.isTracking ? Colors.greenAccent : colorScheme.secondary,
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _controller.tripType,
                dropdownColor: colorScheme.surface,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'pickup', child: Text("To School 🏫")),
                  DropdownMenuItem(value: 'dropoff', child: Text("To Home 🏠")),
                ],
                onChanged: (val) {
                  if (val != null) _controller.tripType = val;
                },
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _controller.toggleTrip(_showMessage),
            icon: Icon(_controller.isTracking ? Icons.stop : Icons.play_arrow),
            label: Text(_controller.isTracking ? "STOP TRIP" : "START TRIP"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _controller.isTracking ? Colors.redAccent : colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(ColorScheme colorScheme) {
    return Expanded(
      flex: 2,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
        ),
        child: _controller.selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: kIsWeb
                    ? Image.network(_controller.selectedImage!.path, fit: BoxFit.cover, width: double.infinity)
                    : Image.file(File(_controller.selectedImage!.path), fit: BoxFit.cover, width: double.infinity),
              )
            : Center(
                child: Icon(Icons.camera_enhance_outlined, size: 50, color: colorScheme.secondary),
              ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    bool disabled = _controller.isLoading || _controller.currentBusId == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: disabled ? null : () => _controller.processImage(ImageSource.camera, _showMessage),
              icon: const Icon(Icons.face_unlock_outlined),
              label: const Text("Scan Face"),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: disabled ? null : () => _controller.processImage(ImageSource.gallery, _showMessage),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              side: BorderSide(color: colorScheme.secondary),
            ),
            child: Icon(Icons.photo_library_outlined, color: colorScheme.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("On Board Students", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_controller.students.isNotEmpty)
            Row(
              children: [
                TextButton(
                  onPressed: () => _controller.dropOffAll(_showMessage),
                  style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
                  child: const Text("DROP OFF ALL", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: _controller.clearStudentsList,
                  style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
                  child: const Text("Clear"),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStudentList(ColorScheme colorScheme) {
    if (_controller.isLoading) {
      return const Expanded(flex: 3, child: Center(child: CircularProgressIndicator()));
    }
    if (_controller.students.isEmpty) {
      return Expanded(
        flex: 3,
        child: Center(
          child: Opacity(
            opacity: 0.5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off_outlined, size: 60, color: colorScheme.secondary),
                const SizedBox(height: 10),
                const Text("No students on board"),
              ],
            ),
          ),
        ),
      );
    }
    return Expanded(
      flex: 3,
      child: ListView.builder(
        itemCount: _controller.students.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final s = _controller.students[index];
          return Card(
            color: colorScheme.primaryContainer,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: colorScheme.primary,
                child: Text(s['name'][0], style: const TextStyle(color: Colors.white)),
              ),
              title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Status: ${s['status']}", style: TextStyle(color: colorScheme.secondary, fontSize: 12)),
              trailing: ElevatedButton(
                onPressed: () => _controller.markAsDroppedOff(s['doc_id'], index, _showMessage),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("DROP OFF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAbsentees() async {
    final absentees = await _controller.getAbsentees();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: const Text("Today's Absentees"),
        content: SizedBox(
          width: double.maxFinite,
          child: absentees.isEmpty
              ? const Text("No absences recorded for today.")
              : ListView(
                  shrinkWrap: true,
                  children: absentees.map((a) => ListTile(
                    leading: const Icon(Icons.person_off, color: Colors.redAccent),
                    title: Text(a['student_name'] ?? 'Unknown'),
                    subtitle: Text("Reason: ${a['reason']}", style: const TextStyle(fontSize: 12)),
                  )).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
