import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  late final DatabaseReference _txRef;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _txRef = FirebaseDatabase.instance.ref('transactions');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: Colors.amber,
      ),
      body: _uid == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<DatabaseEvent>(
              stream: _txRef.orderByChild('uid').equalTo(_uid).onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text('No transactions yet'));
                }

                final raw = snapshot.data!.snapshot.value;
                final List<_TxItem> items = [];
                if (raw is Map) {
                  raw.forEach((key, val) {
                    if (val is Map) {
                      items.add(_TxItem.fromMap(Map<String, dynamic>.from(val)));
                    }
                  });
                } else if (raw is List) {
                  for (final val in raw) {
                    if (val is Map) {
                      items.add(_TxItem.fromMap(Map<String, dynamic>.from(val)));
                    }
                  }
                }

                // Sort by timeIn desc (fallback to status/timeOut/time)
                items.sort((a, b) {
                  final aT = a.timeIn ?? '';
                  final bT = b.timeIn ?? '';
                  return (bT).compareTo(aT);
                });

                if (items.isEmpty) {
                  return const Center(child: Text('No transactions yet'));
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tx = items[index];
                    final String dateStr = _formatDate(tx.timeIn) ?? '-';
                    final String timeInStr = _formatDateTime(tx.timeIn) ?? '-';
                    final String timeOutStr = _formatDateTime(tx.timeOut) ?? '-';
                    final String status = tx.status ?? '-';
                    final double fee = tx.amountToPay ?? tx.amount ?? 0.0;

                    return ListTile(
                      leading: const Icon(Icons.receipt_long, color: Colors.black),
                      title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Time In: ' + timeInStr),
                          Text('Time Out: ' + timeOutStr),
                          Text('Status: ' + status),
                        ],
                      ),
                      trailing: Text('₱' + fee.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                );
              },
            ),
    );
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MM-dd-yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String? _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MM-dd-yyyy hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _TxItem {
  final String? txId;
  final String? uid;
  final String? timeIn;
  final String? timeOut;
  final String? status;
  final double? amountToPay;
  final double? amount;

  _TxItem({
    required this.txId,
    required this.uid,
    required this.timeIn,
    required this.timeOut,
    required this.status,
    required this.amountToPay,
    required this.amount,
  });

  factory _TxItem.fromMap(Map<String, dynamic> m) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString();
      return double.tryParse(s);
    }

    return _TxItem(
      txId: m['txId']?.toString(),
      uid: m['uid']?.toString(),
      timeIn: m['timeIn']?.toString(),
      timeOut: m['timeOut']?.toString(),
      status: m['status']?.toString(),
      amountToPay: toDouble(m['amountToPay']),
      amount: toDouble(m['amount']),
    );
  }
}
