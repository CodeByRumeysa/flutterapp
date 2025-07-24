class User {
  String username;
  int level;
  int xp;
  String avatar; 
  int balance;
  List<Goal> goals;
  List<Friend> friends;

  User({
    required this.username,
    this.level = 1,
    this.xp = 0,
    this.avatar = 'avatar1.png',
    this.balance = 0,
    this.goals = const [],
    this.friends = const [],
  });
}

class Friend {
  String name;
  int level;
  int xp;
  String goal;

  Friend({
    required this.name,
    required this.level,
    required this.xp,
    required this.goal,
  });
}

class Goal {
  String name;
  int targetAmount;
  int savedAmount;
  int durationMonths;

  Goal({
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.durationMonths,
  });
}

class Transaction {
  String description;
  int amount;
  bool isIncome; 
  DateTime date;

  Transaction({
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.date,
  });
}
