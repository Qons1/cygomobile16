import 'package:flutter/material.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'vehicle_selection_screen.dart'; // Import your VehicleSelectionScreen

class WelcomeScreen extends StatelessWidget {
  final String userName;
  final String profileImageUrl;

  const WelcomeScreen({
    super.key,
    required this.userName,
    required this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        userName: userName,
        profileImageUrl: profileImageUrl, // URL or local asset path
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

            const Text(
              "Welcome To CYGO Parking System!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            const Text("Available Slots", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),

            Container(
              width: 500,
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.yellow[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      alignment: Alignment.topCenter,
                      child: const Text("Car", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  Container(width: 1, color: Colors.white),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      alignment: Alignment.topCenter,
                      child: const Text("Motorcycle", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Slide to proceed button → VehicleSelectionScreen
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 400,
                child: SlideAction(
                  borderRadius: 25,
                  text: "Slide to Proceed to Parking",
                  textStyle: const TextStyle(
                    color: Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                  ),
                  outerColor: Colors.amber,
                  innerColor: Colors.white,
                  onSubmit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehicleSelectionScreen(),
                      ),
                    );
                  },
                  sliderButtonIcon: const Icon(Icons.arrow_forward, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
