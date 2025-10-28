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
  final nameController = TextEditingController();
  final contactController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;

  String generateUniqueId() {
    final random = Random();
    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(999999).toString();
  }

  Future<void> register() async {
    setState(() => loading = true);
    try {
      // Validate modern password rules: >=8, upper, lower, number, special
      final pwd = passwordController.text.trim();
      final re = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$');
      if (!re.hasMatch(pwd)) {
        setState(() => loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password must be 8+ chars with upper, lower, number, and special char.')),
          );
        }
        return;
      }
      // Validate passwords match
      if (confirmPasswordController.text.trim() != passwordController.text.trim()) {
        setState(() => loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match')),
          );
        }
        return;
      }
      // Create Firebase Auth user
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCred.user!.uid;
      try {
        await userCred.user!.sendEmailVerification();
      } catch(_) {}
      String qrCodeData = generateUniqueId();

      // Save user details in Realtime Database
      await FirebaseDatabase.instance.ref("users/$uid").set({
        "displayName": nameController.text.trim(),
        "contactNumber": contactController.text.trim(),
        "email": emailController.text.trim(),
        "isPWD": false,
        "pwdStatus": "none",
        "qrCodeData": qrCodeData,
        "activeTransaction": null
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check your email to verify your account.')),
      );
      if (mounted) Navigator.pop(context);
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
        child: SingleChildScrollView( // prevents overflow when keyboard opens
          child: Column(
            children: [
              Image.asset(
                'assets/image.png',
                height: 200,
                width: 200,
              ),
              const SizedBox(height: 20.0),

              // Name input
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),

              // Contact input
              TextField(
                controller: contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Contact Number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),

              // Email input
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),

              // Password input
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: "Re-type Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30.0),

              // Register button
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

              // Cancel button
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
      ),
    );
  }
}
