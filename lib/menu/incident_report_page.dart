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
  List<_Incident> _myIncidents = [];

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
  void initState() {
    super.initState();
    _subscribeMyIncidents();
  }

  void _subscribeMyIncidents() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseDatabase.instance.ref('incidents');
    ref.onValue.listen((event) {
      final val = event.snapshot.value;
      final List<_Incident> items = [];
      if (val is Map) {
        val.forEach((key, v) {
          if (v is Map && (v['uid']?.toString() == uid)) {
            items.add(_Incident.fromMap(key.toString(), Map<String, dynamic>.from(v)));
          }
        });
      }
      items.sort((a,b)=> (b.timestamp??'').compareTo(a.timestamp??''));
      setState(()=> _myIncidents = items);
      // Prompt for pending user confirm
      for (final inc in items) {
        if ((inc.status??'').toUpperCase() == 'PENDING_USER_CONFIRM') {
          _promptResolve(inc);
        }
      }
    });
  }

  Future<void> _promptResolve(_Incident inc) async {
    if (!mounted) return;
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: Text('Issue resolved?'),
        content: Text('Issue "${inc.description ?? ''}" resolved?'),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: ()=> Navigator.pop(context, true), child: const Text('Yes')),
        ],
      )
    );
    if (res == true) {
      await _finalizeIncident(inc.id, true);
    } else if (res == false) {
      // reopen
      await FirebaseDatabase.instance.ref('incidents/'+inc.id).update({ 'status': 'OPEN' });
    }
  }

  Future<void> _finalizeIncident(String id, bool resolved) async {
    final ref = FirebaseDatabase.instance.ref('incidents/'+id);
    if (resolved) {
      await ref.update({ 'status': 'RESOLVED', 'resolvedAt': DateTime.now().millisecondsSinceEpoch });
    } else {
      await ref.update({ 'status': 'OPEN' });
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
                    const SizedBox(height: 24),
                    Align(alignment: Alignment.centerLeft, child: Text('My Submitted Reports', style: TextStyle(fontWeight: FontWeight.bold)) ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _myIncidents.isEmpty
                        ? const Center(child: Text('No reports yet'))
                        : ListView.separated(
                            itemCount: _myIncidents.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index){
                              final inc = _myIncidents[index];
                              final st = (inc.status??'');
                              return ListTile(
                                title: Text(inc.description ?? ''),
                                subtitle: Text('${inc.timestamp ?? ''}  •  ${st}'),
                                trailing: (st.toUpperCase() != 'RESOLVED')
                                  ? TextButton(
                                      onPressed: ()=> _finalizeIncident(inc.id, true),
                                      child: const Text('Resolve')
                                    )
                                  : const Icon(Icons.check, color: Colors.green),
                              );
                            },
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

class _Incident {
  final String id;
  final String? uid;
  final String? description;
  final String? imageUrl;
  final String? timestamp;
  final String? status;
  final String? incidentId;
  _Incident({required this.id, this.uid, this.description, this.imageUrl, this.timestamp, this.status, this.incidentId});
  factory _Incident.fromMap(String id, Map<String, dynamic> m){
    return _Incident(
      id: id,
      uid: m['uid']?.toString(),
      description: m['description']?.toString(),
      imageUrl: m['imageUrl']?.toString(),
      timestamp: m['timestamp']?.toString(),
      status: m['status']?.toString(),
      incidentId: m['incidentId']?.toString(),
    );
  }
}