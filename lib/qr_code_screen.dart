import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'menu/payment_page.dart'; // make sure you have this import
import 'welcome_screen.dart';

class QRCodeScreen extends StatefulWidget {
  final String vehicleType;
  final String? existingTxId;
  const QRCodeScreen({super.key, required this.vehicleType, this.existingTxId});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  String? uid;
  String displayName = 'User';
  String profileImageUrl = '';
  String slot = '';
  String vehicleTypeStr = '';
  double ratePerHour = 0;
  String timeIn = '';
  String timeOut = '';
  String status = 'PENDING_ENTRY';
  String txId = '';
  bool saving = true;
  String qrData = '';
  bool isPWD = false;
  double discountPercent = 0.0;
  double amountToPay = 0.0; // <-- added to pass to payment page
  Stream<DatabaseEvent>? _txStream;
  bool _entryAllowedPresent = true; // block completion until exit scanner clears it
  Stream<DatabaseEvent>? _occStream; // listen to slot occupancy to detect exit

  @override
  void initState() {
    super.initState();
    if (widget.existingTxId != null && widget.existingTxId!.isNotEmpty) {
      _loadExistingTransaction(widget.existingTxId!);
    } else {
      _loadUserAndCreateTransaction();
    }
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

    // 3. Do not assign slot/timeIn here. They will be set when QR is scanned at entry.
    vehicleTypeStr = widget.vehicleType;

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
      'slot': null,
      'timeIn': null,
      'timeOut': null,
      'durationHours': null,
      'ratePerHour': ratePerHour,
      'discountPercent': isPWD ? discountPercent : 0.0,
      'discountAmount': null,
      'amountToPay': null,
      'amountPaid': 0,
      'status': 'PENDING_ENTRY',
    };

    await txRef.set(txData);

    // 6. Link active transaction to user
    await db.child('users/$uid/activeTransaction').set(txId);

    _listenToTransaction(txId);

    setState(() {
      saving = false;
    });
  }

  Future<void> _loadExistingTransaction(String tx) async {
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
    final txSnap = await db.child('transactions/$tx').get();
    if (!txSnap.exists) {
      setState(() {
        saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active transaction found.')),
      );
      return;
    }
    final data = Map<String, dynamic>.from(txSnap.value as Map);
    txId = (data['txId'] ?? tx).toString();
    slot = (data['slot'] ?? '').toString();
    timeIn = (data['timeIn'] ?? '').toString();
    status = (data['status'] ?? 'PENDING_ENTRY').toString();
    ratePerHour = (data['ratePerHour'] ?? 0).toDouble();
    discountPercent = (data['discountPercent'] ?? 0).toDouble();
    amountToPay = (data['amountToPay'] ?? 0).toDouble();
    vehicleTypeStr = (data['vehicleType'] ?? widget.vehicleType).toString();

    _listenToTransaction(txId);

    setState(() {
      saving = false;
    });
  }

  void _listenToTransaction(String id) {
    _txStream = FirebaseDatabase.instance.ref('transactions/' + id).onValue;
    _txStream!.listen((event) {
      final snapVal = event.snapshot.value;
      if (snapVal is Map) {
        final data = Map<String, dynamic>.from(snapVal);
        setState(() {
          slot = (data['slot'] ?? '').toString();
          timeIn = (data['timeIn'] ?? '').toString();
          timeOut = (data['timeOut'] ?? '').toString();
          status = (data['status'] ?? status).toString();
          ratePerHour = (data['ratePerHour'] ?? ratePerHour).toDouble();
          discountPercent = (data['discountPercent'] ?? discountPercent).toDouble();
          amountToPay = (data['amountToPay'] ?? amountToPay ?? 0).toDouble();
          vehicleTypeStr = (data['vehicleType'] ?? vehicleTypeStr).toString();
          _entryAllowedPresent = data.containsKey('entryAllowed');
        });

        // Attach occupancy listener once slot is known
        if (slot.isNotEmpty) {
          _attachOccupancyListener(slot);
        }
      }
    });
  }

  void _attachOccupancyListener(String slotName) {
    _occStream?.drain();
    final safeKey = _sanitizeKey(slotName);
    _occStream = FirebaseDatabase.instance.ref('configurations/layout/occupied/' + safeKey).onValue;
    _occStream!.listen((e) async {
      final v = e.snapshot.value;
      if (v is Map) {
        final st = (v['status'] ?? '').toString().toUpperCase();
        if (st != 'OCCUPIED' && status.toUpperCase() == 'COMPLETED') {
          // Exit occurred; finalize and go home
          await _finalizeAndGoHome();
        }
      } else {
        // Node absent -> treated as free
        if (status.toUpperCase() == 'COMPLETED') {
          await _finalizeAndGoHome();
        }
      }
    });
  }

  Future<void> _finalizeAndGoHome() async {
    try {
      if (txId.isNotEmpty && uid != null) {
        final db = FirebaseDatabase.instance.ref();
        final String nowIso = DateTime.now().toUtc().toIso8601String();
        // Ensure timeOut exists
        await db.child('transactions/' + txId).update({'timeOut': nowIso});
        // Read latest transaction snapshot
        final txSnap = await db.child('transactions/' + txId).get();
        Map<String, dynamic> tx = {};
        if (txSnap.exists && txSnap.value is Map) {
          tx = Map<String, dynamic>.from(txSnap.value as Map);
        }
        final Map<String, dynamic> history = {
          'txId': txId,
          'uid': uid,
          'slot': (tx['slot'] ?? '').toString(),
          'vehicleType': (tx['vehicleType'] ?? widget.vehicleType).toString(),
          'timeIn': (tx['timeIn'] ?? '').toString(),
          'timeOut': (tx['timeOut'] ?? nowIso).toString(),
          'status': (tx['status'] ?? 'COMPLETED').toString(),
          'ratePerHour': (tx['ratePerHour'] ?? 0),
          'discountPercent': (tx['discountPercent'] ?? 0),
          'amountToPay': (tx['amountToPay'] ?? 0),
          'amountPaid': (tx['amountPaid'] ?? 0),
          'plateNumber': (tx['plateNumber'] ?? '').toString(),
          'plateImageUrl': (tx['plateImageUrl'] ?? '').toString(),
          'createdAt': nowIso,
        };
        await db.child('transactionHistory/' + uid! + '/' + txId).set(history);
        await db.child('users/' + uid! + '/activeTransaction').set(null);
      }
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(userName: displayName, profileImageUrl: profileImageUrl),
        ),
        (route) => false,
      );
    }
  }

  Future<String?> _selectSlotDisplayName(bool userIsPwd, String vehicleType) async {
    final DatabaseReference root = FirebaseDatabase.instance.ref('configurations/layout');
    final labelsSnap = await root.child('labels').get();
    Map<String, dynamic> labelsMap = {};
    if (labelsSnap.exists && labelsSnap.value is Map) {
      labelsMap = Map<String, dynamic>.from(labelsSnap.value as Map);
    }

    // Fetch occupied slots map
    final occupiedSnap = await root.child('occupied').get();
    final Map<String, dynamic> occupiedMap = occupiedSnap.exists && occupiedSnap.value is Map
        ? Map<String, dynamic>.from(occupiedSnap.value as Map)
        : <String, dynamic>{};

    final layoutSnap = await root.child('slotsByFloor').get();
    if (!layoutSnap.exists) {
      return null;
    }

    final String vehicleUpper = vehicleType.toUpperCase();

    final dynamic floorsVal = layoutSnap.value;

    if (floorsVal is Map) {
      for (final dynamic entry in floorsVal.entries) {
        final dynamic types = entry.value;
        final String? name = _pickFromTypesFlexible(
          types,
          userIsPwd: userIsPwd,
          isCar: vehicleUpper == 'CAR',
          labelsMap: labelsMap,
          occupiedMap: occupiedMap,
        );
        if (name != null && name.isNotEmpty) return name;
      }
    } else if (floorsVal is List) {
      for (final dynamic types in floorsVal) {
        final String? name = _pickFromTypesFlexible(
          types,
          userIsPwd: userIsPwd,
          isCar: vehicleUpper == 'CAR',
          labelsMap: labelsMap,
          occupiedMap: occupiedMap,
        );
        if (name != null && name.isNotEmpty) return name;
      }
    }

    return null;
  }

  String? _pickFromTypesFlexible(
    dynamic types, {
    required bool userIsPwd,
    required bool isCar,
    required Map<String, dynamic> labelsMap,
    required Map<String, dynamic> occupiedMap,
  }) {
    if (types is! Map) return null;
    // Build candidate keys by fuzzy matching
    final List<String> keys = types.keys.map((k) => k.toString()).toList();
    final List<String> ordered = [];
    for (final k in keys) {
      final kl = k.toLowerCase();
      final isPwdKey = kl.contains('pwd') || kl.contains('accessible') || kl.contains('handicap');
      final isCarKey = kl.contains('car') || kl.contains('four') || kl.contains('4');
      final isMotorKey = kl.contains('motor') || kl.contains('bike') || kl.contains('2');
      final vehicleMatch = isCar ? isCarKey || !isMotorKey : isMotorKey || !isCarKey;
      if (userIsPwd) {
        if (isPwdKey && vehicleMatch) ordered.add(k);
      }
    }
    // If no PWD-specific keys found (or user not PWD), fall back to general type keys
    if (ordered.isEmpty) {
      for (final k in keys) {
        final kl = k.toLowerCase();
        final isPwdKey = kl.contains('pwd') || kl.contains('accessible') || kl.contains('handicap');
        if (isPwdKey) continue; // skip PWD group when not needed
        final isCarKey = kl.contains('car') || kl.contains('four') || kl.contains('4');
        final isMotorKey = kl.contains('motor') || kl.contains('bike') || kl.contains('2');
        final vehicleMatch = isCar ? isCarKey || !isMotorKey : isMotorKey || !isCarKey;
        if (vehicleMatch) ordered.add(k);
      }
    }
    for (final key in ordered) {
      final dynamic slotList = types[key];
      if (slotList is List && slotList.isNotEmpty) {
        for (final dynamic item in slotList) {
          String? candidate;
          if (item is String) {
            candidate = item; // already a display name
          } else if (item is Map) {
            candidate = (item['name'] as String?) ?? (item['label'] as String?);
            if (candidate == null || candidate.isEmpty) {
              final String? id = item['id']?.toString();
              if (id != null && labelsMap.containsKey(id)) {
                final dynamic mapped = labelsMap[id];
                if (mapped is String && mapped.isNotEmpty) candidate = mapped;
              }
            }
          }
          if (candidate != null && candidate.isNotEmpty) {
            final keySan = _sanitizeKey(candidate);
            final occ = occupiedMap[keySan];
            final bool isOcc = occ is Map ? ((occ['status']?.toString().toUpperCase() ?? '') == 'OCCUPIED') : occ != null;
            if (!isOcc) return candidate;
          }
        }
      }
    }
    return null;
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
                          // QR only (no details until scanned)
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

                          // Show details only after scanned (timeIn present or status changed)
                          if (timeIn.isNotEmpty || status != 'PENDING_ENTRY')
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _buildDetailRow('Transaction ID', txId),
                                    _buildDetailRow('Slot', slot.isEmpty ? '-' : slot),
                                    _buildDetailRow('Vehicle', vehicleTypeStr.isNotEmpty ? vehicleTypeStr : widget.vehicleType),
                                    _buildDetailRow('Time In', timeIn.isEmpty ? '-' : _formatDateTime(timeIn)),
                                    if (amountToPay > 0)
                                      _buildDetailRow('Total Fee', '₱${amountToPay.toStringAsFixed(2)}'),
                                    if (isPWD)
                                      _buildDetailRow('PWD Discount',
                                          '${(discountPercent * 100).toStringAsFixed(0)}%'),
                                    if (timeOut.isNotEmpty)
                                      _buildDetailRow('Time Out', _formatDateTime(timeOut)),
                                    _buildDetailRow('Status', status, valueColor: Colors.green),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 30),

                          // Slider: proceed to payment after scanned
                          if (timeIn.isNotEmpty && (status != 'COMPLETED'))
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SizedBox(
                                width: 400,
                                child: SlideAction(
                                  borderRadius: 25,
                                  text: "Proceed to Payment",
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
                                  sliderButtonIcon: const Icon(Icons.arrow_forward, color: Colors.black),
                                ),
                              ),
                            )
                          else if (status.toUpperCase() == 'COMPLETED')
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Scan to Exit',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                                  ),
                                ),
                              ),
                            ),

                          // removed simulate button
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

  Future<void> _simulateEntryScan() async {
    if (txId.isEmpty || uid == null) return;
    final db = FirebaseDatabase.instance.ref();
    final now = DateTime.now().toUtc().toIso8601String();
    final selectedSlotName = await _selectSlotDisplayName(isPWD, vehicleTypeStr.isNotEmpty ? vehicleTypeStr : widget.vehicleType);
    final slotName = selectedSlotName ?? 'A1';
    await db.child('transactions/' + txId).update({
      'status': 'ONGOING',
      'timeIn': now,
      'slot': slotName,
      'discountAmount': 0,
      'amountToPay': ratePerHour,
    });

    // Mark slot as occupied for admin monitoring
    final safeKey = _sanitizeKey(slotName);
    await db.child('configurations/layout/occupied/' + safeKey).set({
      'uid': uid,
      'txId': txId,
      'status': 'OCCUPIED',
      'timeIn': now,
      'vehicleType': vehicleTypeStr.isNotEmpty ? vehicleTypeStr : widget.vehicleType,
      'slotName': slotName,
    });
  }

  String _sanitizeKey(String input) {
    // Firebase keys cannot contain / . # $ [ ] and control chars
    return input
        .replaceAll('/', '_')
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('[', '(')
        .replaceAll(']', ')')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\u0000', '')
        .replaceAll('\u0008', '')
        .replaceAll('\u0009', '')
        .replaceAll('\u000B', '')
        .replaceAll('\u000C', '')
        .replaceAll('\u000D', '');
  }
}