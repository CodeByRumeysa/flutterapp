import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChatPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();

  late String chatId;
  String currentUserAvatar = '';
  String friendAvatar = '';

  @override
  void initState() {
    super.initState();
    final currentUserId = _auth.currentUser!.uid;
    chatId = currentUserId.hashCode <= widget.friendId.hashCode
        ? '$currentUserId-${widget.friendId}'
        : '${widget.friendId}-$currentUserId';
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    final currentUserDoc =
        await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    final friendDoc =
        await _firestore.collection('users').doc(widget.friendId).get();

    setState(() {
      currentUserAvatar = currentUserDoc['avatarPath'] ?? '';
      friendAvatar = friendDoc['avatarPath'] ?? '';
    });
  }

  void sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': _auth.currentUser!.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  Widget _buildMessageItem(DocumentSnapshot messageDoc) {
    final messageId = messageDoc.id;
    final messageText = messageDoc['text'] ?? '';
    final isMe = messageDoc['senderId'] == _auth.currentUser!.uid;
    final avatarUrl = isMe ? currentUserAvatar : friendAvatar;

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: isMe ? Radius.circular(16) : Radius.circular(0),
      bottomRight: isMe ? Radius.circular(0) : Radius.circular(16),
    );

    return Dismissible(
      key: Key(messageId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message deleted')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl.startsWith('assets/')
                    ? AssetImage(avatarUrl) as ImageProvider
                    : (avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null),
                child: avatarUrl.isEmpty ? Icon(Icons.person, size: 16) : null,
              ),
            if (!isMe) SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue[300] : Colors.grey[300],
                  borderRadius: borderRadius,
                ),
                child: Text(
                  messageText,
                  style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87, fontSize: 16),
                ),
              ),
            ),
            if (isMe) SizedBox(width: 8),
            if (isMe)
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl.startsWith('assets/')
                    ? AssetImage(avatarUrl) as ImageProvider
                    : (avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null),
                child: avatarUrl.isEmpty ? Icon(Icons.person, size: 16) : null,
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
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: friendAvatar.startsWith('assets/')
                  ? AssetImage(friendAvatar) as ImageProvider
                  : (friendAvatar.isNotEmpty ? NetworkImage(friendAvatar) : null),
              child: friendAvatar.isEmpty ? Icon(Icons.person) : null,
            ),
            SizedBox(width: 12),
            Text(widget.friendName),
            Spacer(),
            // Clear chat icon
            IconButton(
              icon: Icon(Icons.delete_forever),
              tooltip: 'Clear chat',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Clear Chat'),
                    content:
                        Text('Are you sure you want to delete all messages?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  final messagesSnapshot = await _firestore
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .get();

                  for (var doc in messagesSnapshot.docs) {
                    await doc.reference.delete();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Chat cleared')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) => _buildMessageItem(messages[i]),
                );
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      fillColor: Colors.grey[200],
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
