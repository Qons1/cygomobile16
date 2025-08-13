import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUserName);
    _profileImageController = TextEditingController(text: widget.currentProfileImageUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final updatedName = _nameController.text.trim();
    final updatedImageUrl = _profileImageController.text.trim();

    // TODO: Add save logic here (e.g., update Firebase user profile)

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!')),
    );

    Navigator.pop(context, {
      'userName': updatedName,
      'profileImageUrl': updatedImageUrl,
    });
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saveProfile,
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
