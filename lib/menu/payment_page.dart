// payment_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String userName = '';
  String profileImageUrl = '';
  String slot = '';
  String timeIn = '';
  String? timeOut;
  double ratePerHour = 0;
  double discountPercent = 0;
  double discountAmount = 0;
  double amountToPay = 0;
  String? txId;
  bool loading = true;
  bool paying = false;

  @override
  void initState() {
    super.initState();
    _loadActiveTransaction();
  }

  Future<void> _loadActiveTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }
    userName = user.displayName ?? (user.email ?? 'User');
    profileImageUrl = user.photoURL ?? '';

    final db = FirebaseDatabase.instance.ref();
    final userSnap = await db.child('users/${user.uid}').get();
    String? activeTxId = userSnap.child('activeTransaction').value as String?;
    if (activeTxId == null) {
      setState(() => loading = false);
      return;
    }
    final txSnap = await db.child('transactions/$activeTxId').get();
    if (!txSnap.exists) {
      setState(() => loading = false);
      return;
    }
    final data = Map<String, dynamic>.from(txSnap.value as Map);
    txId = data['txId'] as String?;
    slot = (data['slot'] ?? '') as String;
    timeIn = (data['timeIn'] ?? '') as String;
    timeOut = data['timeOut'] as String?;
    ratePerHour = (data['ratePerHour'] ?? 0).toDouble();
    discountPercent = (data['discountPercent'] ?? 0).toDouble();
    discountAmount = (data['discountAmount'] ?? 0).toDouble();
    amountToPay = (data['amountToPay'] ?? 0).toDouble();

    setState(() => loading = false);
  }

  Future<void> _startGcashPayment() async {
    if (txId == null || paying) return;
    setState(() => paying = true);

    try {
      // Replace with your backend endpoint that creates a GCash source/checkout session
      // The backend should call PayMongo/Maya API with your secret key and return a checkout URL
      final uri = Uri.parse('https://your-backend.example.com/gcash/create');
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'txId': txId,
            'amount': (amountToPay * 100).round(), // in cents
            'description': 'Parking fee for slot ' + slot,
          }));
      if (resp.statusCode != 200) {
        throw Exception('Unable to initiate GCash payment');
      }
      final jsonBody = json.decode(resp.body) as Map<String, dynamic>;
      final checkoutUrl = jsonBody['checkoutUrl'] as String?;
      if (checkoutUrl == null) throw Exception('No checkout URL');

      final uriToLaunch = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uriToLaunch)) {
        await launchUrl(uriToLaunch, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open GCash URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Payment failed: ' + e.toString())));
      }
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        userName: userName,
        profileImageUrl: profileImageUrl,
      ),
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.amber,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row('Slot', slot),
                  _row('Time In', _formatDateTime(timeIn)),
                  _row('Time Out', timeOut == null ? '-' : _formatDateTime(timeOut!)),
                  _row('Rate/Hour', ratePerHour.toStringAsFixed(2)),
                  _row('Discount %', (discountPercent * 100).toStringAsFixed(0) + '%'),
                  _row('Discount Amount', discountAmount.toStringAsFixed(2)),
                  const Divider(),
                  _row('Total Fee', amountToPay.toStringAsFixed(2), isBold: true),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: paying ? null : _startGcashPayment,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      icon: const Icon(Icons.account_balance_wallet),
                      label: paying
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Pay via GCash'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MM-dd-yyyy hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
