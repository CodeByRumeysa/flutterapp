import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class GoalsScreen extends StatefulWidget {
  @override
  _GoalsScreenState createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin {
  final _goalController = TextEditingController();
  final _amountController = TextEditingController();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> activeGoals = [];
  List<Map<String, dynamic>> completedGoals = [];
  late String userId;

  Map<String, TextEditingController> _addControllers = {};

  int level = 1;
  bool completedExpanded = false;

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  Set<String> notifiedGoals = {};

  @override
  void initState() {
    super.initState();

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initNotificationPlugin();

    final user = auth.currentUser;
    if (user != null) {
      userId = user.uid;
      loadGoals();
    }
  }

  void _initNotificationPlugin() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  void _showNotification(String goalName) async {
    const androidDetails = AndroidNotificationDetails(
      'goal_progress_channel',
      'Goal Progress Notifications',
      channelDescription: 'Notifies when goal progress reaches threshold',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notifDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Goal Progress Alert!',
      'You have reached 90% progress on "$goalName".',
      notifDetails,
      payload: goalName,
    );
  }

  @override
  void dispose() {
    _goalController.dispose();
    _amountController.dispose();
    _addControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void loadGoals() {
    firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) async {
      List<Map<String, dynamic>> active = [];
      List<Map<String, dynamic>> completed = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id;

        num savedAmount = (data['savedAmount'] as num?)?.toInt() ?? 0;
        num targetAmount = (data['targetAmount'] as num?)?.toInt() ?? 0;

        int score = targetAmount == 0 ? 0 : ((savedAmount / targetAmount) * 100).floor();
        score = score.clamp(0, 100);
        data['score'] = score;

        if (!notifiedGoals.contains(data['id']) && score >= 90 && score < 100) {
          _showNotification(data['goalName'] ?? "Goal");
          notifiedGoals.add(data['id']);
        }

        if (savedAmount >= targetAmount && targetAmount > 0) {
          completed.add(data);
        } else {
          active.add(data);
        }

        if (!_addControllers.containsKey(data['id'])) {
          _addControllers[data['id']] = TextEditingController();
        }
      }

      int newLevel = completed.length;
      await firestore.collection('users').doc(userId).set({'level': newLevel}, SetOptions(merge: true));

      setState(() {
        activeGoals = active;
        completedGoals = completed;
        level = newLevel;
      });
    });
  }

  Future<void> saveGoalToFirestore(String name, double amount) async {
    await firestore.collection('users').doc(userId).collection('goals').add({
      'goalName': name,
      'targetAmount': amount,
      'savedAmount': 0.0,
      'date': Timestamp.now(),
    });
  }

  Future<void> updateSavingsInFirestore(String docId, double newSavings) async {
    await firestore.collection('users').doc(userId).collection('goals').doc(docId).update({'savedAmount': newSavings});
  }

  Future<void> deleteGoal(String docId) async {
    await firestore.collection('users').doc(userId).collection('goals').doc(docId).delete();
    _addControllers.remove(docId)?.dispose();
    notifiedGoals.remove(docId);
  }

  Widget goalCard(Map<String, dynamic> goal, bool completed) {
    double targetAmount = goal['targetAmount']?.toDouble() ?? 0;
    double savedAmount = goal['savedAmount']?.toDouble() ?? 0;
    int score = goal['score'] ?? 0;
    final addController = _addControllers[goal['id']]!;
    double progress = targetAmount == 0 ? 0 : (savedAmount / targetAmount);
    progress = progress.clamp(0, 1);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      color: completed ? Colors.green.shade50 : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(completed ? Icons.check_circle_outline : Icons.flag_outlined, color: completed ? Colors.green : Colors.teal),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    goal['goalName'] ?? 'Unnamed Goal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: completed ? TextDecoration.lineThrough : null,
                      color: completed ? Colors.green.shade800 : Colors.teal.shade800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => deleteGoal(goal['id']),
                  tooltip: "Delete Goal",
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearPercentIndicator(
              lineHeight: 16,
              percent: progress,
              backgroundColor: Colors.grey.shade300,
              progressColor: completed ? Colors.green : Colors.teal,
              animation: true,
              animationDuration: 600,
              center: Text("${(progress * 100).toStringAsFixed(1)}%", style: TextStyle(fontSize: 13, color: Colors.white)),
              barRadius: Radius.circular(12),
            ),
            SizedBox(height: 16),
            completed
                ? Text("Target Amount: ₺${targetAmount.toStringAsFixed(2)}",
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade900))
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: addController,
                              decoration: InputDecoration(
                                hintText: "Add amount",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                filled: true,
                                fillColor: Colors.teal.shade50,
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          SizedBox(width: 14),
                          ElevatedButton(
                            onPressed: () async {
                              double added = double.tryParse(addController.text) ?? 0;
                              if (added <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Please enter a valid amount!")));
                                return;
                              }
                              double newSavings = savedAmount + added;
                              await updateSavingsInFirestore(goal['id'], newSavings);
                              addController.clear();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade400,
                              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text("Add", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Saved: ₺${savedAmount.toStringAsFixed(2)} / Target: ₺${targetAmount.toStringAsFixed(2)}",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Goals"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.teal.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Level: $level",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: 16),

           
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 5,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Add New Goal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 12),
                    TextField(
                      controller: _goalController,
                      decoration: InputDecoration(
                        labelText: "Goal Name",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Target Amount (₺)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () async {
                        final name = _goalController.text.trim();
                        final amount = double.tryParse(_amountController.text.trim()) ?? 0;

                        if (name.isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Please enter a valid goal name and amount.")));
                          return;
                        }
                        await saveGoalToFirestore(name, amount);
                        _goalController.clear();
                        _amountController.clear();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Center(
                          child: Text(
                        "Add Goal",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      )),
                    )
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            
            Expanded(
              child: activeGoals.isEmpty
                  ? Center(child: Text("No active goals yet!"))
                  : ListView.builder(
                      itemCount: activeGoals.length,
                      itemBuilder: (context, index) => goalCard(activeGoals[index], false),
                    ),
            ),

           
            GestureDetector(
              onTap: () => setState(() => completedExpanded = !completedExpanded),
              child: Container(
                color: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      completedExpanded ? "Hide Completed Goals" : "Show Completed Goals",
                      style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                    ),
                    Icon(completedExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.teal),
                  ],
                ),
              ),
            ),

            if (completedExpanded)
              Expanded(
                child: completedGoals.isEmpty
                    ? Center(child: Text("No completed goals yet!"))
                    : ListView.builder(
                        itemCount: completedGoals.length,
                        itemBuilder: (context, index) => goalCard(completedGoals[index], true),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
