import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'custom_drawer.dart';
import 'friends_screen.dart';
import 'messages_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  DocumentSnapshot? userData;
  List<Map<String, dynamic>> goals = [];
  bool isLoading = true;

  double totalIncome = 0;
  double totalExpense = 0;

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final transactionSnapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('transactions').get();
    final goalsSnapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('goals').get();

    double incomeSum = 0;
    double expenseSum = 0;

    for (var doc in transactionSnapshot.docs) {
      final data = doc.data();
      final type = data['type'];
      final amount = (data['amount'] ?? 0).toDouble();

      if (type == 'income') {
        incomeSum += amount;
      } else if (type == 'expense') {
        expenseSum += amount;
      }
    }

    setState(() {
      userData = userDoc;
      goals = goalsSnapshot.docs.map((doc) {
        final data = doc.data();
        final double savedAmount = (data['savedAmount'] ?? 0).toDouble();
        final double targetAmount = (data['targetAmount'] ?? 1).toDouble(); // division by zero önleme
        return {
          'name': data['goalName'] ?? 'Goal',
          'savedAmount': savedAmount,
          'targetAmount': targetAmount,
          'progress': (savedAmount / targetAmount).clamp(0, 1.0),
        };
      }).where((goal) => goal['progress'] < 1.0).toList();

      totalIncome = incomeSum;
      totalExpense = expenseSum;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = userData!.data() as Map<String, dynamic>;
    double balance = totalIncome - totalExpense;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
  children: [
    CircleAvatar(
      radius: 40,
      backgroundImage: data['avatarPath'] != null
          ? AssetImage(data['avatarPath'])
          : null,
      child: data['avatarPath'] == null
          ? const Icon(Icons.person, size: 40)
          : null,
    ),
    Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.yellowAccent, size: 16),
            const SizedBox(width: 4),
            Text(
              "${data['level'] ?? 0}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ),
  ],
),

                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    data['displayName'] ?? 'User',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.group),
                  tooltip: 'Friends',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  FriendsScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.message),
                  tooltip: 'Messages',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  MessagesScreen()),
                    );
                  },
                ),
              ],
            ),

            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRow("📈 Total Income:", "${totalIncome.toStringAsFixed(2)} ₺"),
                    const SizedBox(height: 8),
                    _buildRow("💸 Expenses:", "${totalExpense.toStringAsFixed(2)} ₺"),
                    const SizedBox(height: 8),
                    _buildRow("💰 Remaining Balance:", "${balance.toStringAsFixed(2)} ₺"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text("🎯 Goals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            ...goals.map((goal) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal['name'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "${goal['savedAmount'].toStringAsFixed(2)} / ${goal['targetAmount'].toStringAsFixed(2)} ₺",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: goal['progress'],
                  backgroundColor: Colors.grey[300],
                  color: Colors.blue,
                  minHeight: 8,
                ),
                const SizedBox(height: 4),
                Text("%${(goal['progress'] * 100).toStringAsFixed(0)} completed"),
                const SizedBox(height: 12),
              ],
            )),

            const SizedBox(height: 10),

            const Text("📊 Progress Chart", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            AspectRatio(
              aspectRatio: 1.7,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  title: AxisTitle(text: 'Goal'),
                  labelRotation: 45,
                ),
                primaryYAxis: NumericAxis(
                  minimum: 0,
                  maximum: 100,
                  title: AxisTitle(text: 'Progress (%)'),
                ),
                series: <CartesianSeries>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: goals,
                    xValueMapper: (goal, _) => goal['name'],
                    yValueMapper: (goal, _) => goal['progress'] * 100,
                    color: Colors.teal,
                    width: 0.7,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String title, String value) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class ProgressData {
  final int index;
  final double progress;

  ProgressData(this.index, this.progress);
}
