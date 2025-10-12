import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class MockPayPage extends StatefulWidget {
  final String txId;
  final double amount;
  final String merchantName;

  const MockPayPage({super.key, required this.txId, required this.amount, this.merchantName = 'CYGO Parking'});

  @override
  State<MockPayPage> createState() => _MockPayPageState();
}

class _MockPayPageState extends State<MockPayPage> {
  bool _processing = false;

  Future<void> _completePayment() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final db = FirebaseDatabase.instance.ref();
      final txId = widget.txId;
      final amount = widget.amount;

      await db.child('payments/$txId').set({
        'txId': txId,
        'amount': amount,
        'method': 'MOCKPAY',
        'referenceNumber': 'MOCK-${txId.substring(0, txId.length >= 6 ? 6 : txId.length)}',
        'status': 'PAID',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      await db.child('transactions/$txId').update({
        'status': 'COMPLETED',
        'amountPaid': amount,
        'timeOut': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountDisp = '₱' + widget.amount.toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('GCash', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF007BFF), Color(0xFF0052CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: const Color(0xFFF2F5F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Card(children: [
              _Row(label: 'Pay to', value: widget.merchantName),
              _Row(label: 'Method', value: 'GCash'),
              _Row(label: 'Reference (TxID)', value: widget.txId, clampRight: true),
            ]),
            _Card(children: [
              _Row(label: 'Amount Due', value: amountDisp, isAmount: true),
              _Row(label: 'Convenience Fee', value: '₱0.00'),
              _Row(label: 'Total', value: amountDisp, isAmount: true),
            ]),
            _Card(children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing ? null : _completePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    shadowColor: const Color(0x40007BFF),
                    elevation: 4,
                  ),
                  child: Text(_processing ? 'Processing…' : 'Pay Now'),
                ),
              ),
              const SizedBox(height: 10),
              const Text('This is a mock checkout for testing only.', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isAmount;
  final bool clampRight;
  const _Row({required this.label, required this.value, this.isAmount = false, this.clampRight = false});
  @override
  Widget build(BuildContext context) {
    final valueWidget = clampRight
        ? Expanded(child: Text(value, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontWeight: isAmount ? FontWeight.w800 : FontWeight.w600, fontSize: isAmount ? 22 : 14)))
        : Text(value, style: TextStyle(fontWeight: isAmount ? FontWeight.w800 : FontWeight.w600, fontSize: isAmount ? 22 : 14));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))) ,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          if (clampRight) valueWidget else Flexible(child: valueWidget),
        ],
      ),
    );
  }
}


