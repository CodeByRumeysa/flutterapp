import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  late String userId;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final user = auth.currentUser;
    if (user != null) userId = user.uid;
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    final snapshot = await firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    List<Map<String, dynamic>> results = [];

    for (var doc in snapshot.docs) {
      if (doc.id == userId) continue;

      var friendDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(doc.id)
          .get();

      var sentRequestDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('sentRequests')
          .doc(doc.id)
          .get();

      var data = doc.data();

      results.add({
        'uid': doc.id,
        'name': data['displayName'],
        'avatarPath': data.containsKey('avatarPath') ? data['avatarPath'] : null,
        'isFriend': friendDoc.exists,
        'requestSent': sentRequestDoc.exists,
      });
    }

    setState(() => searchResults = results);
  }

  Future<void> sendFriendRequest(String friendId, String friendName) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('sentRequests')
        .doc(friendId)
        .set({'name': friendName, 'sentAt': Timestamp.now()});

    final currentUserDoc = await firestore.collection('users').doc(userId).get();
    final currentUserData = currentUserDoc.data();
    final currentUserName = currentUserData?['displayName'] ?? '';
    final currentUserAvatar = (currentUserData != null && currentUserData.containsKey('avatarPath'))
        ? currentUserData['avatarPath']
        : null;

    await firestore
        .collection('users')
        .doc(friendId)
        .collection('friendRequests')
        .doc(userId)
        .set({
      'name': currentUserName,
      'avatarPath': currentUserAvatar,
      'requestedAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friend request sent')),
    );
  }
Future<void> acceptRequest(String requesterId, String requesterName) async {
  
  final currentUserDoc = await firestore.collection('users').doc(userId).get();
  final currentUserData = currentUserDoc.data();
  final currentUserName = currentUserData?['displayName'] ?? '';
  final currentUserAvatar = currentUserData?['avatarPath'] ?? '';
  final currentUserLevel = currentUserData?['level'] ?? 1;

  final requesterDoc = await firestore.collection('users').doc(requesterId).get();
  final requesterData = requesterDoc.data();
  final requesterAvatar = requesterData?['avatarPath'] ?? '';
  final requesterLevel = requesterData?['level'] ?? 1;

  final timestamp = Timestamp.now();

  
  await firestore
      .collection('users')
      .doc(requesterId)
      .collection('friends')
      .doc(userId)
      .set({
    'name': currentUserName,
    'avatarPath': currentUserAvatar,
    'level': currentUserLevel,
    'addedAt': timestamp,
  });

  
  await firestore
      .collection('users')
      .doc(userId)
      .collection('friends')
      .doc(requesterId)
      .set({
    'name': requesterName,
    'avatarPath': requesterAvatar,
    'level': requesterLevel,
    'addedAt': timestamp,
  });

  
  await firestore.collection('users').doc(userId).collection('friendRequests').doc(requesterId).delete();
  await firestore.collection('users').doc(requesterId).collection('sentRequests').doc(userId).delete();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Friend request accepted')),
  );
}


  Future<void> rejectRequest(String requesterId) async {
    await firestore.collection('users').doc(userId).collection('friendRequests').doc(requesterId).delete();

    await firestore.collection('users').doc(requesterId).collection('sentRequests').doc(userId).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friend request rejected')),
    );
  }

  Widget buildAvatar(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: AssetImage('assets/avatars/default.png'),
      );
    } else if (avatarUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl),
      );
    } else {
      return CircleAvatar(
        radius: 28,
        backgroundImage: AssetImage(avatarUrl),
      );
    }
  }

  Widget buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search friends',
              hintText: 'Enter a name...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: () => searchUsers(_searchController.text.trim()),
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onSubmitted: (val) => searchUsers(val.trim()),
          ),
          SizedBox(height: 20),
          Expanded(
            child: searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 12),
                        Text(
                          'No results found',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      var user = searchResults[index];
                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: buildAvatar(user['avatarPath']),
                          title: Text(user['name'], style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: user['isFriend']
                              ? Chip(
                                  label: Text('Friend', style: TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.green,
                                )
                              : user['requestSent']
                                  ? Chip(
                                      label: Text('Request Sent', style: TextStyle(color: Colors.white)),
                                      backgroundColor: Colors.orange,
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: StadiumBorder(),
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: Text('Send Request'),
                                      onPressed: () => sendFriendRequest(user['uid'], user['name']),
                                    ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('users').doc(userId).collection('friendRequests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());

        var requests = snapshot.data?.docs ?? [];

        return requests.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_disabled, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 12),
                    Text('No incoming requests', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  var req = requests[index];
                  var id = req.id;
                  var data = req.data() as Map<String, dynamic>;
                  var name = data['name'];
                  var avatarPath = data.containsKey('avatarPath') ? data['avatarPath'] : null;

                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: buildAvatar(avatarPath),
                      title: Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => acceptRequest(id, name),
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => rejectRequest(id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
      },
    );
  }

  Widget buildFriendsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('users').doc(userId).collection('friends').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());

        var friendsDocs = snapshot.data?.docs ?? [];

        if (friendsDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                SizedBox(height: 12),
                Text('No friends found', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: friendsDocs.length,
          itemBuilder: (context, index) {
            var friendId = friendsDocs[index].id;
            return FutureBuilder<DocumentSnapshot>(
              future: firestore.collection('users').doc(friendId).get(),
              builder: (context, friendSnapshot) {
                if (!friendSnapshot.hasData) return SizedBox();

                var friendData = friendSnapshot.data!.data() as Map<String, dynamic>;
                var friendName = friendData['displayName'];
                var avatarPath = friendData.containsKey('avatarPath') ? friendData['avatarPath'] : null;

                return Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ExpansionTile(
                    leading: buildAvatar(avatarPath),
                    title: Text(friendName, style: TextStyle(fontWeight: FontWeight.w600)),
                    children: [
                      FutureBuilder<QuerySnapshot>(
                        future: firestore
                            .collection('users')
                            .doc(friendId)
                            .collection('goals')
                            .get(),
                        builder: (context, goalsSnapshot) {
                          if (!goalsSnapshot.hasData)
                            return Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Center(child: CircularProgressIndicator()),
                            );

                          var goalsDocs = goalsSnapshot.data!.docs;

                          if (goalsDocs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('No goals found for this friend.'),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: goalsDocs.map((goalDoc) {
                                var goalData = goalDoc.data() as Map<String, dynamic>;

                                double savedAmount = 0;
                                double targetAmount = 1; // Avoid division by zero

                                if (goalData['savedAmount'] != null) {
                                  savedAmount = (goalData['savedAmount'] as num).toDouble();
                                }
                                if (goalData['targetAmount'] != null && (goalData['targetAmount'] as num).toDouble() > 0) {
                                  targetAmount = (goalData['targetAmount'] as num).toDouble();
                                }

                                double progress = (savedAmount / targetAmount).clamp(0.0, 1.0);
                                String level = friendData['level']?.toString() ?? '';



                                String goalName = goalData['goalName'] ?? 'Unnamed Goal';

                                return Container(
                                  margin: EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(goalName, style: TextStyle(fontWeight: FontWeight.bold)),
                                      SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 10,
                                        backgroundColor: Colors.grey[300],
                                        color: Colors.blue,
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${savedAmount.toStringAsFixed(2)} / ${targetAmount.toStringAsFixed(2)}'),
                                          Text('Level: $level'),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Search'),
            Tab(text: 'Requests'),
            Tab(text: 'Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildSearchTab(),
          buildRequestsTab(),
          buildFriendsTab(),
        ],
      ),
    );
  }
}
