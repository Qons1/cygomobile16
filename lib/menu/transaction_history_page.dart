import 'package:flutter/material.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Example data
    final transactions = [
      {"date": "2025-08-01", "amount": "₱50", "status": "Paid"},
      {"date": "2025-08-05", "amount": "₱40", "status": "Paid"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaction History"),
        backgroundColor: Colors.amber,
      ),
      body: ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final tx = transactions[index];
          return ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text("Date: ${tx['date']}"),
            subtitle: Text("Amount: ${tx['amount']}"),
            trailing: Text(
              tx['status']!,
              style: const TextStyle(color: Colors.green),
            ),
          );
        },
      ),
    );
  }
}
