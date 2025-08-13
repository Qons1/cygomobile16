// app_drawer.dart
import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'menu/apply_pwd_page.dart';
import 'menu/transaction_history_page.dart';
import 'menu/incident_report_page.dart';
import 'menu/payment_page.dart';
import 'menu/edit_profile_page.dart'; // Import your EditProfilePage


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
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile picture
            CircleAvatar(
              radius: 50,
              backgroundImage: profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : const AssetImage('assets/profile.png') as ImageProvider,
            ),
            const SizedBox(height: 10),

            // User name
            Text(
              userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

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
            _drawerMenuItem(
              context,
              icon: Icons.home,
              label: "Home",
              page: WelcomeScreen(
                userName: userName,
                profileImageUrl: profileImageUrl,
              ),
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
                onPressed: () {
                  // Handle logout
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
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}
