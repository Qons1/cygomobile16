import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'menu/payment_page.dart'; // make sure you have this import

class QRCodeScreen extends StatefulWidget {
  final String vehicleType;
  const QRCodeScreen({super.key, required this.vehicleType});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  String? uid;
  String displayName = 'User';
  String profileImageUrl = '';
  String slot = '';
  double ratePerHour = 0;
  String timeIn = '';
  String status = 'ONGOING';
  String txId = '';
  bool saving = true;
  String qrData = '';
  bool isPWD = false;
  double discountPercent = 0.0;
  double amountToPay = 0.0; // <-- added to pass to payment page

  @override
  void initState() {
    super.initState();
    _loadUserAndCreateTransaction();
  }

  Future<void> _loadUserAndCreateTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authenticated user. Please login.')),
      );
      return;
    }

    uid = user.uid;
    displayName = user.displayName ?? (user.email ?? 'User');
    profileImageUrl = user.photoURL ?? '';
    qrData = 'CYGO:$uid';

    final db = FirebaseDatabase.instance.ref();

    // 1. Get global config (rates, discount)
    final configSnap = await db.child('config').get();
    if (configSnap.exists) {
      final cfg = Map<String, dynamic>.from(configSnap.value as Map);
      ratePerHour = widget.vehicleType.toUpperCase() == 'CAR'
          ? (cfg['carRatePerHour'] ?? 50).toDouble()
          : (cfg['motorcycleRatePerHour'] ?? 20).toDouble();
      discountPercent = (cfg['pwdDiscountPercent'] ?? 0).toDouble();
    } else {
      ratePerHour =
          widget.vehicleType.toUpperCase() == 'CAR' ? 50.0 : 20.0; // fallback
      discountPercent = 0.2;
    }

    // 2. Get user profile (check if PWD approved)
    final userSnap = await db.child('users/$uid').get();
    if (userSnap.exists) {
      final userData = Map<String, dynamic>.from(userSnap.value as Map);
      isPWD = userData['isPWD'] == true &&
          (userData['pwdStatus'] ?? '') == 'approved';
    } else {
      // Create initial user record if not exists
      await db.child('users/$uid').set({
        'displayName': displayName,
        'email': user.email ?? '',
        'isPWD': false,
        'pwdStatus': 'none',
        'qrData': qrData,
        'activeTransaction': null,
      });
    }

    // 3. Assign parking slot (temporary logic)
    slot = widget.vehicleType.toUpperCase() == 'CAR' ? 'A1' : 'M1';
    timeIn = DateTime.now().toIso8601String();

    // 4. Calculate fee
    double baseAmount = ratePerHour;
    double discount = isPWD ? discountPercent * baseAmount : 0.0;
    amountToPay = baseAmount - discount; // store to send to payment page

    // 5. Save transaction
    final txRef = db.child('transactions').push();
    txId = txRef.key ?? DateTime.now().millisecondsSinceEpoch.toString();

    final txData = {
      'txId': txId,
      'uid': uid,
      'vehicleType': widget.vehicleType,
      'slot': slot,
      'timeIn': timeIn,
      'timeOut': null,
      'durationHours': null,
      'ratePerHour': ratePerHour,
      'discountPercent': isPWD ? discountPercent : 0.0,
      'discountAmount': discount,
      'amountToPay': amountToPay,
      'amountPaid': 0,
      'status': status,
    };

    await txRef.set(txData);

    // 6. Link active transaction to user
    await db.child('users/$uid/activeTransaction').set(txId);

    setState(() {
      saving = false;
    });
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: valueColor ?? Colors.black)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        userName: displayName,
        profileImageUrl: profileImageUrl,
      ),
      body: saving
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Top bar with logo + menu button
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 25.0),
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

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Permanent QR
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 300,
                                    gapless: false,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Present this QR at exit/entry scanner',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Transaction details
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  _buildDetailRow('Transaction ID', txId),
                                  _buildDetailRow('Slot', slot),
                                  _buildDetailRow('Vehicle', widget.vehicleType),
                                  _buildDetailRow('Time In', timeIn),
                                  _buildDetailRow(
                                      'Rate/Hour', '₱${ratePerHour.toStringAsFixed(2)}'),
                                  if (isPWD)
                                    _buildDetailRow('PWD Discount',
                                        '${(discountPercent * 100).toStringAsFixed(0)}%'),
                                  _buildDetailRow('Status', status,
                                      valueColor: Colors.green),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Slider Button instead of Done Button
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: 400,
                              child: SlideAction(
                                borderRadius: 25,
                                text: "Slide to Proceed to Payment",
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
                                      builder: (context) => const PaymentPage(),
                                    ),
                                  );
                                },
                                sliderButtonIcon:
                                    const Icon(Icons.arrow_forward, color: Colors.black),
                              ),
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
}