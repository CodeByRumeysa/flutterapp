import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class MoneyScreen extends StatefulWidget {
  final String uid;
  const MoneyScreen({super.key, required this.uid});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  List<Map<String, dynamic>> incomes = [];
  List<Map<String, dynamic>> expenses = [];

  final incomeController = TextEditingController();
  final expenseAmountController = TextEditingController();
  final expenseCategoryController = TextEditingController();

  DateTime incomeDate = DateTime.now();
  DateTime expenseDate = DateTime.now();

  bool isLoading = false;

  DateTime filterStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime filterEndDate = DateTime.now();

  final DateFormat dateFormatter = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    final start = Timestamp.fromDate(filterStartDate);
    final end = Timestamp.fromDate(filterEndDate.add(const Duration(days: 1)));

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('transactions');

    final incomeSnap = await collection
        .where('type', isEqualTo: 'income')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .orderBy('date', descending: true)
        .get();

    final expenseSnap = await collection
        .where('type', isEqualTo: 'expense')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .orderBy('date', descending: true)
        .get();

    incomes = incomeSnap.docs.map((doc) => {
          'id': doc.id,
          'amount': (doc['amount'] as num).toDouble(),
          'date': (doc['date'] as Timestamp).toDate(),
        }).toList();

    expenses = expenseSnap.docs.map((doc) => {
          'id': doc.id,
          'amount': (doc['amount'] as num).toDouble(),
          'category': doc['category'],
          'date': (doc['date'] as Timestamp).toDate(),
        }).toList();

    setState(() => isLoading = false);
  }

  double get totalIncome =>
      incomes.fold(0, (sum, item) => sum + (item['amount'] ?? 0));

  double get totalExpenses =>
      expenses.fold(0, (sum, item) => sum + (item['amount'] ?? 0));

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _addIncome() async {
    final amount = double.tryParse(incomeController.text) ?? 0;
    if (amount <= 0) {
      _showSnackBar("Please enter a valid income amount.");
      return;
    }

    setState(() => isLoading = true);

    final normalizedDate = _normalizeDate(incomeDate);
    final startOfDay = Timestamp.fromDate(normalizedDate);
    final endOfDay = Timestamp.fromDate(normalizedDate.add(const Duration(days: 1)));

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('transactions');

    final existing = await collection
        .where('type', isEqualTo: 'income')
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThan: endOfDay)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await collection.doc(existing.docs.first.id).update({
        'amount': amount,
        'date': startOfDay,
      });
    } else {
      await collection.add({
        'type': 'income',
        'amount': amount,
        'date': startOfDay,
      });
    }

    incomeController.clear();
    await _fetchData();

    setState(() => isLoading = false);
  }

  Future<void> _addExpense() async {
    final amount = double.tryParse(expenseAmountController.text) ?? 0;
    final category = expenseCategoryController.text.trim();

    if (amount <= 0 || category.isEmpty) {
      _showSnackBar("Please enter all expense details.");
      return;
    }

    setState(() => isLoading = true);

    final normalizedDate = _normalizeDate(expenseDate);
    final startOfDay = Timestamp.fromDate(normalizedDate);
    final endOfDay = Timestamp.fromDate(normalizedDate.add(const Duration(days: 1)));

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('transactions');

    final existing = await collection
        .where('type', isEqualTo: 'expense')
        .where('category', isEqualTo: category)
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThan: endOfDay)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await collection.doc(existing.docs.first.id).update({
        'amount': amount,
        'date': startOfDay,
        'category': category,
      });
    } else {
      await collection.add({
        'type': 'expense',
        'amount': amount,
        'category': category,
        'date': startOfDay,
      });
    }

    expenseAmountController.clear();
    expenseCategoryController.clear();
    await _fetchData();

    setState(() => isLoading = false);
  }

  Future<void> _deleteTransaction(String id) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('transactions')
        .doc(id)
        .delete();
    await _fetchData();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filterStartDate,
      firstDate: DateTime(2000),
      lastDate: filterEndDate,
    );
    if (picked != null && picked != filterStartDate) {
      setState(() => filterStartDate = picked);
      await _fetchData();
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filterEndDate,
      firstDate: filterStartDate,
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != filterEndDate) {
      setState(() => filterEndDate = picked);
      await _fetchData();
    }
  }

  Future<void> _selectIncomeDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: incomeDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != incomeDate) {
      setState(() => incomeDate = picked);
    }
  }

  Future<void> _selectExpenseDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != expenseDate) {
      setState(() => expenseDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartData = [
      _ChartData('Income', totalIncome, Colors.green),
      _ChartData('Expense', totalExpenses, Colors.red),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Money Management'),
        backgroundColor: Colors.purple.shade800,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => _selectStartDate(context),
                          child: Text("Start: ${dateFormatter.format(filterStartDate)}"),
                        ),
                        ElevatedButton(
                          onPressed: () => _selectEndDate(context),
                          child: Text("End: ${dateFormatter.format(filterEndDate)}"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text(
                              "Add Income",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            TextField(
                              controller: incomeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _selectIncomeDate(context),
                              child: Text('Date: ${dateFormatter.format(incomeDate)}'),
                            ),
                            ElevatedButton(
                              onPressed: _addIncome,
                              child: const Text("Save Income"),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                   
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text(
                              "Add Expense",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            TextField(
                              controller: expenseAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixIcon: Icon(Icons.money_off),
                              ),
                            ),
                            TextField(
                              controller: expenseCategoryController,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(Icons.category),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _selectExpenseDate(context),
                              child: Text('Date: ${dateFormatter.format(expenseDate)}'),
                            ),
                            ElevatedButton(
                              onPressed: _addExpense,
                              child: const Text("Save Expense"),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Income List
                    if (incomes.isNotEmpty) ...[
                      const Text(
                        "Income List",
                        style:
                            TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: incomes.length,
                        itemBuilder: (context, index) {
                          final item = incomes[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                  "Amount: \$${item['amount'].toStringAsFixed(2)}"),
                              subtitle: Text(
                                  "Date: ${dateFormatter.format(item['date'])}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteTransaction(item['id']),
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    
                    if (expenses.isNotEmpty) ...[
                      const Text(
                        "Expense List",
                        style:
                            TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final item = expenses[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                  "Amount: \$${item['amount'].toStringAsFixed(2)}"),
                              subtitle: Text(
                                  "Category: ${item['category']}\nDate: ${dateFormatter.format(item['date'])}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteTransaction(item['id']),
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    
                    SfCircularChart(
                      legend: Legend(isVisible: true),
                      series: <CircularSeries>[
                        PieSeries<_ChartData, String>(
                          dataSource: chartData,
                          xValueMapper: (_ChartData data, _) => data.category,
                          yValueMapper: (_ChartData data, _) => data.amount,
                          pointColorMapper: (_ChartData data, _) => data.color,
                          dataLabelSettings: const DataLabelSettings(isVisible: true),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ChartData {
  final String category;
  final double amount;
  final Color color;

  _ChartData(this.category, this.amount, this.color);
}
