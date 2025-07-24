import 'package:flutter/material.dart';

class IncomeExpenseScreen extends StatefulWidget {
  const IncomeExpenseScreen({super.key});

  @override
  State<IncomeExpenseScreen> createState() => _IncomeExpenseScreenState();
}

class _IncomeExpenseScreenState extends State<IncomeExpenseScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isIncome = true;
  double _balance = 1000.0; // Starting balance (example)
  List<Map<String, dynamic>> _transactions = [];

  void _addTransaction() {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showMessage("Please enter an amount");
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showMessage("Please enter a valid amount");
      return;
    }

    final description = _descriptionController.text.trim();

    setState(() {
      if (_isIncome) {
        _balance += amount;
      } else {
        _balance -= amount;
      }

      _transactions.add({
        'type': _isIncome ? 'Income' : 'Expense',
        'amount': amount,
        'description': description,
        'date': DateTime.now(),
      });

      _amountController.clear();
      _descriptionController.clear();
    });

    _showMessage("Transaction saved");
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return const Text("No transactions yet");
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return ListTile(
          leading: Icon(
            tx['type'] == 'Income' ? Icons.arrow_upward : Icons.arrow_downward,
            color: tx['type'] == 'Income' ? Colors.green : Colors.red,
          ),
          title: Text(
            "${tx['type']}: \$${tx['amount'].toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: tx['description'] != ''
              ? Text("Description: ${tx['description']}")
              : null,
          trailing: Text(
            "${tx['date'].hour.toString().padLeft(2, '0')}:${tx['date'].minute.toString().padLeft(2, '0')}",
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Income / Expense Entry")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Remaining Balance: \$${_balance.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Income'),
                  selected: _isIncome,
                  onSelected: (selected) {
                    setState(() {
                      _isIncome = true;
                    });
                  },
                  selectedColor: Colors.green[300],
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Expense'),
                  selected: !_isIncome,
                  onSelected: (selected) {
                    setState(() {
                      _isIncome = false;
                    });
                  },
                  selectedColor: Colors.red[300],
                ),
              ],
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 15),

            if (!_isIncome)
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Expense Description",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.amber[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Save", style: TextStyle(fontSize: 18)),
              ),
            ),

            const SizedBox(height: 20),

            const Text("Transaction History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            Expanded(child: _buildTransactionList()),
          ],
        ),
      ),
    );
  }
}
