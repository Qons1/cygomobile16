// payment_page.dart
import 'package:flutter/material.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'mockpay_page.dart';
import '../qr_code_screen.dart';

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
  String txStatus = '';
  String txVehicleType = 'CAR';
  bool loading = true;
  bool paying = false; // deprecated, kept for state; we'll switch to submitting
  bool submitting = false;
  final String gcashName = 'CYGO Parking';

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
    txStatus = (data['status'] ?? '').toString();
    txVehicleType = (data['vehicleType'] ?? 'CAR').toString();

    // Compute based on time consumed
    if (timeIn.isNotEmpty) {
      try {
        final DateTime inDt = DateTime.parse(timeIn).toLocal();
        final DateTime outDt = (timeOut != null && timeOut!.isNotEmpty)
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

  Future<void> _openGCashToPay() async {
    if (amountToPay <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Total fee not available yet. Ensure your QR was scanned at entry.')),
        );
      }
      return;
    }
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MockPayPage(txId: txId!, amount: amountToPay, merchantName: 'CYGO Parking'),
      ),
    );
    if (changed == true) {
      await _loadActiveTransaction();
      if (txStatus.toUpperCase() == 'COMPLETED' && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QRCodeScreen(vehicleType: txVehicleType, existingTxId: txId!),
          ),
        );
      }
    }
  }

  Future<void> _openMockPay() async {
    if (txId == null || amountToPay <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Total fee not available yet. Ensure your QR was scanned at entry.')),
        );
      }
      return;
    }
    try {
      // lazy import to avoid tight coupling
      // ignore: prefer_interpolation_to_compose_strings
      final page = await _resolveMockPayPage();
      if (!mounted) return;
      final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      if (changed == true) {
        // reload data
        await _loadActiveTransaction();
      }
    } catch (_) {}
  }

  Future<Widget> _resolveMockPayPage() async {
    // avoid static import; using runtime import-like structure
    return MockPayPage(txId: txId!, amount: amountToPay, merchantName: 'CYGO Parking');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        userName: userName,
        profileImageUrl: profileImageUrl,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Top bar with logo + menu button (like ApplyPWD)
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

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _row('Slot', slot.isEmpty ? '-' : slot),
                          _row('Time In', timeIn.isEmpty ? '-' : _formatDateTime(timeIn)),
                          const Divider(),
                          _row('Total Fee', '₱' + amountToPay.toStringAsFixed(2), isBold: true),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _openGCashToPay,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                              child: const Text('Pay with GCash'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
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
