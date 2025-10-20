import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_page.dart'; // your current HomePage file
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _RootWithIncidentWatcher(child: HomePage()),
    );
  }
}

class _RootWithIncidentWatcher extends StatefulWidget {
  final Widget child;
  const _RootWithIncidentWatcher({required this.child});
  @override
  State<_RootWithIncidentWatcher> createState() => _RootWithIncidentWatcherState();
}

class _RootWithIncidentWatcherState extends State<_RootWithIncidentWatcher> {
  DatabaseReference? _ref;
  Stream<DatabaseEvent>? _sub;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void dispose() {
    _sub?.drain();
    super.dispose();
  }

  void _attach() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    _uid = u.uid;
    _ref = FirebaseDatabase.instance.ref('incidents');
    _sub = _ref!.onValue.listen((event) async {
      final val = event.snapshot.value;
      if (val is Map) {
        for (final entry in val.entries) {
          final String id = entry.key.toString();
          final dynamic v = entry.value;
          if (v is Map && (v['uid']?.toString() == _uid)) {
            final String st = (v['status'] ?? '').toString().toUpperCase();
            if (st == 'PENDING_USER_CONFIRM') {
              final String desc = (v['description'] ?? '').toString();
              if (!mounted) return;
              final bool? res = await showDialog<bool>(
                context: navigatorKey.currentContext ?? context,
                barrierDismissible: true,
                builder: (_) => AlertDialog(
                  title: const Text('Issue resolved?'),
                  content: Text('Issue "' + desc + '" resolved?'),
                  actions: [
                    TextButton(onPressed: ()=> Navigator.pop(navigatorKey.currentContext ?? context, false), child: const Text('No')),
                    ElevatedButton(onPressed: ()=> Navigator.pop(navigatorKey.currentContext ?? context, true), child: const Text('Yes')),
                  ],
                ),
              );
              final ref = FirebaseDatabase.instance.ref('incidents/' + id);
              if (res == true) {
                await ref.update({ 'status': 'RESOLVED', 'resolvedAt': DateTime.now().millisecondsSinceEpoch });
              } else if (res == false) {
                await ref.update({ 'status': 'OPEN' });
              }
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
