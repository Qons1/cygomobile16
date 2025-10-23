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
  String? _selectedCategory; // visible to user (title)

  // Hidden priority mapping (do not display priority labels on UI)
  static const List<Map<String, String>> _categories = [
    { 'title': 'Vehicle collision with another parked car', 'priority': 'high' },
    { 'title': 'Occupying multiple slots / improper parking', 'priority': 'high' },
    { 'title': 'Unauthorized vehicle in reserved or PWD slot', 'priority': 'high' },
    { 'title': 'Blocking other vehicles (parked too close or behind)', 'priority': 'medium' },
    { 'title': 'Vehicle problem', 'priority': 'medium' },
    { 'title': 'Trash or litter left in slot', 'priority': 'low' },
    { 'title': 'Vandalism (scratches, broken mirrors, graffiti)', 'priority': 'low' },
  ];

  int _priorityWeight(String p){
    switch(p){ case 'high': return 3; case 'medium': return 2; case 'low': return 1; default: return 0; }
  }

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
    if ((_selectedCategory==null) || _selectedCategory!.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final url = await _uploadToCloudinary(_image!);
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed')));
        return;
      }
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final ref = FirebaseDatabase.instance.ref('incidents').push();
      final cat = _categories.firstWhere((m)=> m['title']==_selectedCategory, orElse: ()=> const {'title':'Other','priority':'low'});
      final pr = (cat['priority'] ?? 'low');
      await ref.set({
        'uid': uid,
        'description': descriptionController.text.trim(),
        'imageUrl': url,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'status': 'OPEN',
        'categoryTitle': cat['title'],
        'priority': pr,
        'priorityWeight': _priorityWeight(pr),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident submitted')));
      setState(() {
        _image = null;
        descriptionController.clear();
        _selectedCategory = null;
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
    });
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
                        ? GestureDetector(
                            onTap: (){
                              showDialog(context: context, builder: (_){
                                return Dialog(
                                  insetPadding: const EdgeInsets.all(16),
                                  backgroundColor: Colors.transparent,
                                  child: Stack(children: [
                                    Container(
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(8),
                                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_image!)),
                                    ),
                                  ]),
                                );
                              });
                            },
                            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_image!, height: 220, fit: BoxFit.cover)),
                          )
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
                    // Category dropdown (no priority labels shown to user)
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: _categories.map((m)=> DropdownMenuItem<String>(
                        value: m['title']!, child: Text(m['title']!),
                      )).toList(),
                      onChanged: (v){ setState(()=> _selectedCategory = v); },
                      decoration: const InputDecoration(labelText: 'Select Category', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
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
                              if (st.toUpperCase() == 'RESOLVED') return const SizedBox.shrink();
                              final title = (inc.categoryTitle ?? '').trim();
                              return ListTile(
                                title: Text(
                                  title.isNotEmpty ? '$title — ${inc.description ?? ''}' : (inc.description ?? ''),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('${inc.timestamp ?? ''}  •  ${st}'),
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
  final String? categoryTitle;
  final String? priority;
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
      // optional new fields
      categoryTitle: m['categoryTitle']?.toString(),
      priority: m['priority']?.toString(),
    );
  }
}