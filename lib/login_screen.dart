import 'package:cygo_ps/register_screen.dart';
import 'package:cygo_ps/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cygo_ps/qr_code_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  Future<bool> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final u = FirebaseAuth.instance.currentUser;
      if (u != null && !u.emailVerified) {
        try { await u.sendEmailVerification(); } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified. Verification link sent.')),
        );
        await FirebaseAuth.instance.signOut();
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login successful!')));
      return true;
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error')),
      );
      return false; // If login failed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Image.asset(
              'assets/image.png',
              height: 300,
              width: 300,
            ),
            const SizedBox(height: 50.0),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Email",
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Password",
              ),
              obscureText: true,
            ),
            const SizedBox(height: 100.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(251, 255, 18, 1),
                ),
                onPressed: loading
                    ? null
                    : () async {
                        setState(() => loading = true);

                        bool success = await login();

                        setState(() => loading = false);

                        if (success) {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final snap = await FirebaseDatabase.instance.ref('users/' + user.uid).get();
                            final activeTx = snap.child('activeTransaction').value?.toString();
                            if (activeTx != null && activeTx.isNotEmpty) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => QRCodeScreen(vehicleType: 'CAR', existingTxId: activeTx)),
                                (route) => false,
                              );
                              return;
                            }
                            final display = (snap.child('displayName').value?.toString() ?? user.displayName ?? user.email ?? 'User');
                            final photo = (snap.child('profileImageUrl').value?.toString() ?? user.photoURL ?? '');
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => WelcomeScreen(
                                  userName: display,
                                  profileImageUrl: photo,
                                ),
                              ),
                              (route) => false,
                            );
                            return;
                          }
                        }
                      },
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Login"),
              ),
            ),
            const SizedBox(height: 16.0),
            SizedBox(
              width: 250,
              child: Row(
                children: const [
                  Expanded(
                    child: Divider(
                      thickness: 1,
                      color: Colors.grey,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text("or"),
                  ),
                  Expanded(
                    child: Divider(
                      thickness: 1,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text("Create an account"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
