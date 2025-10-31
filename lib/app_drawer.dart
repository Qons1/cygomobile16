// app_drawer.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'welcome_screen.dart';
import 'menu/apply_pwd_page.dart';
import 'menu/transaction_history_page.dart';
import 'menu/incident_report_page.dart';
import 'menu/payment_page.dart';
import 'menu/edit_profile_page.dart'; // Import your EditProfilePage
import 'login_screen.dart';
import 'qr_code_screen.dart';


class AppDrawer extends StatelessWidget {
  final String userName;
  final String profileImageUrl;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile picture + name (live from Realtime Database)
            if (uid == null) ...[
              CircleAvatar(
                radius: 50,
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : const AssetImage('assets/profile.png') as ImageProvider,
              ),
              const SizedBox(height: 10),
              Text(
                userName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ] else ...[
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('users/' + uid).onValue,
                builder: (context, snapshot) {
                  String display = userName;
                  String photo = profileImageUrl;
                  if (snapshot.hasData && snapshot.data!.snapshot.value is Map) {
                    final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                    if (data['displayName'] is String && (data['displayName'] as String).isNotEmpty) {
                      display = data['displayName'] as String;
                    }
                    if (data['profileImageUrl'] is String && (data['profileImageUrl'] as String).isNotEmpty) {
                      photo = data['profileImageUrl'] as String;
                    } else if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
                      photo = user.photoURL!;
                    }
                  }
                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(photo)
                            : const AssetImage('assets/profile.png') as ImageProvider,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        display,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 10),

            // Edit Profile button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditProfilePage(
                    currentUserName: userName,               // <-- pass userName here
                    currentProfileImageUrl: profileImageUrl,
                  ))
                  ),
                // Navigate to Edit Profile Page
              },
              child: const Text("Edit Profile"),
            ),

            const Divider(),

            // Menu items
            ListTile(
              leading: const Icon(Icons.home, color: Colors.black),
              title: const Text("Home", style: TextStyle(fontSize: 16)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final u = FirebaseAuth.instance.currentUser;
                  if (u != null) {
                    final snap = await FirebaseDatabase.instance.ref('users/' + u.uid).get();
                    final activeTx = snap.child('activeTransaction').value?.toString();
                    if (activeTx != null && activeTx.isNotEmpty) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => QRCodeScreen(vehicleType: 'CAR', existingTxId: activeTx)),
                      );
                      return;
                    }
                  }
                } catch (_) {}
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => WelcomeScreen(
                      userName: userName,
                      profileImageUrl: profileImageUrl,
                    ),
                  ),
                );
              },
            ),
            _drawerMenuItem(
              context,
              icon: Icons.accessible,
              label: "Apply PWD",
              page: ApplyPWDPage(
                userName: userName,
                profileImageUrl: profileImageUrl,
              ),
            ),
            _drawerMenuItem(
              context,
              icon: Icons.receipt_long,
              label: "Transaction History",
              page: const TransactionHistoryPage(),
            ),
            _drawerMenuItem(
              context,
              icon: Icons.report_problem,
              label: "Report Incident",
              page: const IncidentReportPage(),
            ),
            _drawerMenuItem(
              context,
              icon: Icons.payment,
              label: "Payment",
              page: const PaymentPage(),
            ),

            const Spacer(),

            // Logout button
            SizedBox(
              width: 250,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                ),
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout failed: ' + e.toString())),
                      );
                    }
                  }
                },
                child: const Text("LOGOUT"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerMenuItem(BuildContext context,
      {required IconData icon, required String label, required Widget page}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }
}
