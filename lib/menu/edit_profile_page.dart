import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfilePage extends StatefulWidget {
  final String currentUserName;
  final String currentProfileImageUrl;

  const EditProfilePage({
    super.key,
    required this.currentUserName,
    required this.currentProfileImageUrl,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _profileImageController;
  late TextEditingController _contactController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _newAvatar;
  bool _saving = false;

  static const String _cloudName = 'dy5kbbskp';
  static const String _uploadPreset = 'reports_img';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUserName);
    _profileImageController = TextEditingController(text: widget.currentProfileImageUrl);
    _contactController = TextEditingController(text: '');
    _loadCurrentFromDb();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _profileImageController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentFromDb() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseDatabase.instance.ref('users/' + user.uid).get();
    if (snap.exists && snap.value is Map) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      if (data['displayName'] is String && (data['displayName'] as String).isNotEmpty) {
        _nameController.text = data['displayName'] as String;
      }
      if (data['profileImageUrl'] is String && (data['profileImageUrl'] as String).isNotEmpty) {
        _profileImageController.text = data['profileImageUrl'] as String;
      }
      if (data['contactNumber'] is String) {
        _contactController.text = data['contactNumber'] as String;
      }
      setState(() {});
    }
  }

  Future<void> _pickNewAvatar() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _newAvatar = File(picked.path);
      });
    }
  }

  Future<String?> _uploadAvatar(File file) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/' + _cloudName + '/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode != 200 && resp.statusCode != 201) return null;
    final decoded = json.decode(body) as Map<String, dynamic>;
    return decoded['secure_url'] as String?;
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final updatedName = _nameController.text.trim();
    String updatedImageUrl = _profileImageController.text.trim();

    setState(() => _saving = true);
    try {
      if (_newAvatar != null) {
        final url = await _uploadAvatar(_newAvatar!);
        if (url != null) {
          updatedImageUrl = url;
          _profileImageController.text = url;
        }
      }

      // Update Firebase Auth profile
      await user.updateDisplayName(updatedName);
      if (updatedImageUrl.isNotEmpty) {
        await user.updatePhotoURL(updatedImageUrl);
      }

      // Update password if provided and confirmed; enforce strength
      final newPassword = _passwordController.text.trim();
      final newPassword2 = _passwordConfirmController.text.trim();
      if (newPassword.isNotEmpty) {
        final re = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$');
        if (!re.hasMatch(newPassword)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password must be 8+ chars with upper, lower, number, and special char.')),
            );
          }
          setState(() => _saving = false);
          return;
        }
        if (newPassword2 != newPassword) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Passwords do not match')),
            );
          }
          setState(() => _saving = false);
          return;
        }
        await user.updatePassword(newPassword);
      }

      // Update Realtime Database profile
      final updates = <String, dynamic>{
        'displayName': updatedName,
        'profileImageUrl': updatedImageUrl,
      };
      await FirebaseDatabase.instance.ref('users/' + user.uid).update(updates);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated!')));
      Navigator.pop(context, {
        'userName': updatedName,
        'profileImageUrl': updatedImageUrl,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: ' + e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: _newAvatar != null
                  ? FileImage(_newAvatar!)
                  : (widget.currentProfileImageUrl.isNotEmpty
                      ? NetworkImage(widget.currentProfileImageUrl) as ImageProvider
                      : (FirebaseAuth.instance.currentUser?.photoURL != null
                          ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                          : const AssetImage('assets/profile.png'))),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _pickNewAvatar,
              child: const Text('Change Photo'),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Number', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_contactController.text.isEmpty ? 'N/A' : _contactController.text),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _profileImageController,
              decoration: const InputDecoration(
                labelText: 'Profile Image URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordConfirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Re-type New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saving ? null : _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
