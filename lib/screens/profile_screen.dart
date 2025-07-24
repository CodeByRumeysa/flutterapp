import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();

  final List<String> avatarPaths = List.generate(
    22,
    (index) => 'assets/avatars/avatar${index + 1}.png',
  );

  int? selectedAvatarIndex;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data != null) {
        final avatarPath = data['avatarPath'] as String?;
        final displayName = data['displayName'] as String?;

        if (avatarPath != null) {
          selectedAvatarIndex = avatarPaths.indexOf(avatarPath);
        }
        _nameController.text = displayName ?? user.displayName ?? '';
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    final displayName = _nameController.text.trim();
    final avatarPath = selectedAvatarIndex != null ? avatarPaths[selectedAvatarIndex!] : null;

    try {
      // Check for unique username
      final querySnapshot = await _firestore
          .collection('users')
          .where('displayName', isEqualTo: displayName)
          .get();

      final isTaken = querySnapshot.docs.any((doc) => doc.id != user.uid);

      if (isTaken) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This username is already taken. Please try another name.')),
        );
        return;
      }

      await user.updateDisplayName(displayName);
      await user.reload();
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': displayName,
        if (avatarPath != null) 'avatarPath': avatarPath,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      debugPrint("Error saving profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred during update')),
      );
    }

    setState(() => isLoading = false);
  }

  void _showAvatarSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        child: GridView.builder(
          itemCount: avatarPaths.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final isSelected = selectedAvatarIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() => selectedAvatarIndex = index);
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border.all(color: Colors.deepPurple, width: 3)
                      : Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(avatarPaths[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        centerTitle: true,
        backgroundColor: const Color(0xFF601169),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showAvatarSelection,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: CircleAvatar(
                      key: ValueKey(selectedAvatarIndex),
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: selectedAvatarIndex != null
                          ? AssetImage(avatarPaths[selectedAvatarIndex!])
                          : null,
                      child: selectedAvatarIndex == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white70)
                          : null,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.edit, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("displayname", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA97DB7),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
