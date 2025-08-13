import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  String generateUniqueId() {
    final random = Random();
    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(999999).toString();
  }

  Future<void> register() async {
    setState(() => loading = true);
    try {
      // Create Firebase Auth user
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCred.user!.uid;
      String qrCodeData = generateUniqueId();

      // Save user details in Realtime Database
      await FirebaseDatabase.instance.ref("users/$uid").set({
        "email": emailController.text.trim(),
        "isPWD": false,
        "pwdStatus": "none",
        "qrCodeData": qrCodeData,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      Navigator.pop(context); // go back to home
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Image.asset(
              'assets/image.png',
              height: 300,
              width: 300,
            ),
            const SizedBox(height: 50.0),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 200.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(251, 255, 18, 1),
                ),
                onPressed: loading ? null : register,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Register"),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // go back to home
                },
                child: const Text("Cancel"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
