import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'package:cygo_ps/services/firebase_service.dart';

class ApplyPWDPage extends StatefulWidget {
  final String userName;
  final String profileImageUrl;

  const ApplyPWDPage({
    super.key,
    required this.userName,
    required this.profileImageUrl,
  });

  @override
  State<ApplyPWDPage> createState() => _ApplyPWDPageState();
}

class _ApplyPWDPageState extends State<ApplyPWDPage> {
  final TextEditingController _pwdNumberController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImageFile;
  bool _isSubmitting = false;
  final FirebaseService _firebaseService = FirebaseService();
  static const String _cloudName = 'dy5kbbskp';
  static const String _uploadPreset = 'reports_img';
  String? _pwdStatus; // none | pending | approved | rejected/denied
  String? _userPwdStatus;
  String? _requestPwdStatus;
  StreamSubscription<DatabaseEvent>? _statusSubUsers;
  StreamSubscription<DatabaseEvent>? _statusSubRequest;

  @override
  void dispose() {
    _pwdNumberController.dispose();
    _statusSubUsers?.cancel();
    _statusSubRequest?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _listenToPwdStatus();
  }

  Future<void> _listenToPwdStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final usersRef = FirebaseDatabase.instance.ref('users/' + user.uid + '/pwdStatus');
    final reqRef = FirebaseDatabase.instance.ref('pwdRequests/' + user.uid + '/status');

    _statusSubUsers = usersRef.onValue.listen((event) {
      _userPwdStatus = event.snapshot.value?.toString();
      setState(() {
        _pwdStatus = _mergeStatus(_userPwdStatus, _requestPwdStatus);
      });
    });

    _statusSubRequest = reqRef.onValue.listen((event) {
      _requestPwdStatus = event.snapshot.value?.toString();
      setState(() {
        _pwdStatus = _mergeStatus(_userPwdStatus, _requestPwdStatus);
      });
    });
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _selectedImageFile = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    final bool canSubmit = !(_pwdStatus == 'pending' || _pwdStatus == 'approved');
    if (!canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot submit while status is pending or approved.')),
      );
      return;
    }
    if (_selectedImageFile == null || _pwdNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide PWD number and upload your PWD card image.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/' + _cloudName + '/image/upload');
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', _selectedImageFile!.path));
      final resp = await req.send();
      final body = await resp.stream.bytesToString();
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw Exception('Cloudinary upload failed');
      }
      final decoded = json.decode(body) as Map<String, dynamic>;
      final url = decoded['secure_url'] as String?;
      if (url == null) {
        throw Exception('No URL returned from Cloudinary');
      }
      await _firebaseService.submitPWDRequest(
        imageUrl: url,
        pwdNumber: _pwdNumberController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PWD application submitted. Await approval.')),
      );
      setState(() {
        _selectedImageFile = null;
        _pwdNumberController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: ' + e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      drawer: AppDrawer(
        userName: widget.userName,
        profileImageUrl: widget.profileImageUrl,
      ),
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

            // Form inputs wrapped in Padding
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text( 
                    "Apply for PWD Parking",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Text(   
                    "Please enter your PWD ID number and upload a clear photo of your PWD card.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _pwdNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "PWD ID Number",
                      border: OutlineInputBorder(),
                    ),
                    enabled: !(_pwdStatus == 'pending' || _pwdStatus == 'approved'),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: (_pwdStatus == 'pending' || _pwdStatus == 'approved') ? null : _pickImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.upload_file),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedImageFile == null
                                  ? 'Tap to upload PWD card image'
                                  : 'Image selected: ${_selectedImageFile!.path.split('/').last}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedImageFile != null)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedImageFile = null;
                                });
                              },
                              child: const Text('Remove'),
                            )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedImageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImageFile!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      onPressed: (_isSubmitting || _pwdStatus == 'pending' || _pwdStatus == 'approved') ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                            )
                          : const Text("Submit Application"),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _formatStatus(_pwdStatus),
                    style: TextStyle(
                      color: _statusColor(_pwdStatus),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String? raw) {
    if (raw == null || raw == 'none' || raw.isEmpty) return 'None';
    if (raw.toLowerCase() == 'rejected' || raw.toLowerCase() == 'denied') return 'Denied';
    final s = raw.toLowerCase();
    return s[0].toUpperCase() + s.substring(1);
  }

  Color _statusColor(String? raw) {
    final s = (raw ?? '').toLowerCase();
    if (s == 'approved') return Colors.green;
    if (s == 'pending') return Colors.orange;
    if (s == 'rejected' || s == 'denied') return Colors.red;
    return Colors.grey;
  }

  String _mergeStatus(String? userStatus, String? requestStatus) {
    final String a = (userStatus ?? '').toLowerCase();
    final String b = (requestStatus ?? '').toLowerCase();
    // Priority: approved > denied/rejected > pending > none
    if (a == 'approved' || b == 'approved') return 'approved';
    if (a == 'denied' || a == 'rejected' || b == 'denied' || b == 'rejected') return 'denied';
    if (a == 'pending' || b == 'pending') return 'pending';
    return 'none';
  }
}
