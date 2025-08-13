import 'package:flutter/material.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'package:cygo_ps/qr_code_screen.dart'; 


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
        onPressed: () {
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
