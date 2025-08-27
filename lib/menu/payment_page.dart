// payment_page.dart
import 'package:flutter/material.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool paying = false; // deprecated, kept for state; we'll switch to submitting
  bool submitting = false;
  final String gcashName = 'Your GCash Name';
  final String gcashNumber = '09XXXXXXXXX';
  final String gcashNote = 'Use your Tx ID as reference';
  final TextEditingController _referenceController = TextEditingController();

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

    // Fallback compute if amountToPay not yet set in DB but timeIn exists
    if (amountToPay <= 0 && (timeIn.isNotEmpty)) {
      try {
        final DateTime inDt = DateTime.parse(timeIn).toLocal();
        final DateTime outDt = timeOut != null && timeOut!.isNotEmpty
            ? DateTime.parse(timeOut!).toLocal()
            : DateTime.now();
        final totalMinutes = outDt.difference(inDt).inMinutes;
        final hours = (totalMinutes / 60.0);
        final billedHours = hours <= 1.0 ? 1.0 : hours.ceilToDouble();
        final base = billedHours * ratePerHour;
        final discount = base * discountPercent;
        discountAmount = discount;
        amountToPay = (base - discount).clamp(0.0, double.infinity);
      } catch (_) {}
    }

    setState(() => loading = false);
  }

  Future<void> _submitReference() async {
    if (txId == null || submitting) return;
    if (amountToPay <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Total fee not available yet. Ensure your QR was scanned at entry.')),
        );
      }
      return;
    }
    final refNum = _referenceController.text.trim();
    if (refNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your GCash reference number.')),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      await db.child('payments/' + txId!).set({
        'txId': txId,
        'amount': amountToPay,
        'method': 'GCASH_DIRECT',
        'referenceNumber': refNum,
        'status': 'PENDING_VERIFICATION',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      await db.child('transactions/' + txId!).update({
        'status': 'AWAITING_CONFIRMATION',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reference submitted. We will verify your payment shortly.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to submit reference: ' + e.toString())));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _openGCashToPay() async {
    if (amountToPay <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Total fee not available yet. Ensure your QR was scanned at entry.')),
        );
      }
      return;
    }

    final String note = (txId ?? '').isNotEmpty
        ? ('TxID: ' + txId!)
        : gcashNote;

    // Try a few possible GCash deep links. If none work, fall back to copying details.
    final List<Uri> candidates = [
      Uri.parse('gcash://sendmoney?mobile=' + Uri.encodeComponent(gcashNumber) + '&amount=' + Uri.encodeComponent(amountToPay.toStringAsFixed(2)) + '&message=' + Uri.encodeComponent(note)),
      Uri.parse('gcash://pay?phone=' + Uri.encodeComponent(gcashNumber) + '&amount=' + Uri.encodeComponent(amountToPay.toStringAsFixed(2)) + '&note=' + Uri.encodeComponent(note)),
      Uri.parse('gcash://app'),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return;
        }
      } catch (_) {}
    }

    // Fallback: copy details to clipboard and instruct user to open GCash manually
    await Clipboard.setData(ClipboardData(
      text: 'GCash: ' + gcashNumber + ' | Amount: ' + amountToPay.toStringAsFixed(2) + ' | ' + note,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details copied. Open GCash and paste to complete payment.')),
      );
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

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GCash Receiver Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _row('Account Name', gcashName),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Account Number', style: TextStyle(fontWeight: FontWeight.bold)),
                              Row(children: [
                                Text(gcashNumber),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: gcashNumber));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('GCash number copied')),
                                    );
                                  },
                                )
                              ])
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(gcashNote),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openGCashToPay,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Pay with GCash'),
                    ),
                  ),

                  TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Enter GCash Reference Number',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : _submitReference,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      child: submitting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Submit Payment Reference'),
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
