import 'package:flutter/material.dart';
import 'package:cygo_ps/app_drawer.dart';

class ApplyPWDPage extends StatelessWidget {
  final String userName;
  final String profileImageUrl;

  const ApplyPWDPage({
    super.key,
    required this.userName,
    required this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController idNumberController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    return Scaffold(
      drawer: AppDrawer(
        userName: userName,
        profileImageUrl: profileImageUrl,
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
                    "Please fill out the form below to apply for a PWD parking slot.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: idNumberController,
                    decoration: const InputDecoration(
                      labelText: "PWD ID Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Reason",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    onPressed: () {
                      // Submit logic here
                    },
                    child: const Text("Submit Application"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
