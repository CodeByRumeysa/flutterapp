import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_page.dart';

class MessagesScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MessagesScreen({super.key});

  String _getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Messages'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .collection('friends')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No friends added yet.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final friends = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final friendDoc = friends[index];
              final friendId = friendDoc.id;
              final friendData = friendDoc.data() as Map<String, dynamic>? ?? {};
              final friendName = friendData['displayname'] ?? 'Unnamed';

              final chatId = _getChatId(currentUser.uid, friendId);

        
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('chats').doc(chatId).get(),
                builder: (context, chatSnapshot) {
                  if (chatSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading...'),
                    );
                  }
                  if (!chatSnapshot.hasData || !chatSnapshot.data!.exists) {
                    
                    return _buildFriendTile(
                      context,
                      friendId,
                      friendName,
                      0,
                      Colors.deepPurple,
                    );
                  }

                  final chatData = chatSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final Timestamp? lastReadTimestamp = chatData['lastRead'] as Timestamp?;

                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .where('senderId', isEqualTo: friendId)
                        .snapshots(),
                    builder: (context, msgSnapshot) {
                      if (msgSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildFriendTile(
                          context,
                          friendId,
                          friendName,
                          0,
                          Colors.deepPurple,
                        );
                      }

                      int newMessageCount = 0;
                      if (msgSnapshot.hasData) {
                        final messages = msgSnapshot.data!.docs;
                        if (lastReadTimestamp != null) {
                          newMessageCount = messages.where((msg) {
                            final Timestamp sentTime = msg['sentAt'] as Timestamp? ?? Timestamp.now();
                            return sentTime.toDate().isAfter(lastReadTimestamp.toDate()) &&
                                !(msg['isSeen'] ?? false);
                          }).length;
                        } else {
                          // If no lastRead, all messages are considered new
                          newMessageCount = messages.where((msg) => !(msg['isSeen'] ?? false)).length;
                        }
                      }

                      return _buildFriendTile(
                        context,
                        friendId,
                        friendName,
                        newMessageCount,
                        newMessageCount > 0 ? Colors.red : Colors.deepPurple,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
Widget _buildFriendTile(
  BuildContext context,
  String friendId,
  String _,
  int newMessageCount,
  Color titleColor,
) {
  return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('users').doc(friendId).get(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const ListTile(title: Text('Loading...'));
      }

      final userDoc = snapshot.data;
      final userData = userDoc?.data() as Map<String, dynamic>? ?? {};
      final avatarPath = userData['avatarPath'] as String? ?? '';
      final displayName = userData['displayName'] as String? ?? 'Unnamed';

      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          leading: avatarPath.startsWith('assets/')
              ? CircleAvatar(radius: 28, backgroundImage: AssetImage(avatarPath))
              : avatarPath.isNotEmpty
                  ? CircleAvatar(radius: 28, backgroundImage: NetworkImage(avatarPath))
                  : const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurpleAccent,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
          title: Text(
            displayName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
          ),
          subtitle: Text(
            newMessageCount > 0
                ? '$newMessageCount new message${newMessageCount > 1 ? 's' : ''}'
                : 'Tap to chat',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          trailing: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline, color: Colors.deepPurple, size: 30),
              if (newMessageCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      newMessageCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  friendId: friendId,
                  friendName: displayName,
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
}