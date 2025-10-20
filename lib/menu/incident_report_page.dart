import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cygo_ps/app_drawer.dart';

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({super.key});

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  final TextEditingController descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _submitting = false;

  static const String cloudName = 'dy5kbbskp';
  static const String uploadPreset = 'reports_img';

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadToCloudinary(File file) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final jsonBody = json.decode(body) as Map<String, dynamic>;
      return jsonBody['secure_url'] as String?;
    }
    return null;
  }

  Future<void> _submitReport() async {
    if (_image == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final url = await _uploadToCloudinary(_image!);
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed')));
        return;
      }
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final ref = FirebaseDatabase.instance.ref('incidents').push();
      await ref.set({
        'uid': uid,
        'description': descriptionController.text.trim(),
        'imageUrl': url,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'status': 'OPEN',
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident submitted')));
      setState(() {
        _image = null;
        descriptionController.clear();
      });
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? (user?.email ?? 'User');
    final profileImageUrl = user?.photoURL ?? '';

    return Scaffold(
      drawer: AppDrawer(userName: userName, profileImageUrl: profileImageUrl),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with logo + menu button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/image.png', height: 50),
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, size: 28),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _image != null
                        ? Image.file(_image!, height: 220)
                        : Container(
                            height: 220,
                            alignment: Alignment.center,
                            color: Colors.grey[300],
                            child: const Text("No image selected"),
                          ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Camera"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text("Gallery"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: "Incident Description", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                        child: _submitting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Text("Submit Report"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}