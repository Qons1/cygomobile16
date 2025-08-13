// payment_page.dart
import 'package:flutter/material.dart';
import 'package:cygo_ps/app_drawer.dart';

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(
        userName: "John Doe",
        profileImageUrl: "",
      ),
      appBar: AppBar(
        title: const Text("Payment"),
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Select Payment Method",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.black),
              title: const Text("Pay via GCash"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: Integrate GCash API
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.black),
              title: const Text("Pay via Credit/Debit Card"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: Add card payment
              },
            ),
            ListTile(
              leading: const Icon(Icons.money, color: Colors.black),
              title: const Text("Pay with Cash"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: Handle cash payment
              },
            ),
          ],
        ),
      ),
    );
  }
}
