import 'package:flutter/material.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'package:cygo_ps/qr_code_screen.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';


class VehicleSelectionScreen extends StatelessWidget {
  const VehicleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(
        userName: "John Doe",
        profileImageUrl: "",
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

            const SizedBox(height: 10),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Choose Vehicle Type",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  const SizedBox(height: 20),
                  _buildButton(context, "CAR"),
                  const SizedBox(height: 10),
                  _buildButton(context, "MOTORCYCLE"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String vehicleType) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          // Prevent starting a new transaction if there is an active one
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final snap = await FirebaseDatabase.instance.ref('users/' + user.uid).get();
              final activeTx = snap.child('activeTransaction').value?.toString();
              if (activeTx != null && activeTx.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You already have an ongoing transaction. Redirecting...')),
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => QRCodeScreen(vehicleType: 'CAR', existingTxId: activeTx)),
                  (route) => false,
                );
                return;
              }
            }
          } catch (_) {}
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QRCodeScreen(vehicleType: vehicleType),
            ),
          );
        },


        child: Text(
          vehicleType,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
