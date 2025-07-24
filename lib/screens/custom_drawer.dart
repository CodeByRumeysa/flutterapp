import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'messages_screen.dart';
import 'money_screen.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'dart:io';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey[800]),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.blueGrey[800],
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      hoverColor: Colors.blue[50],
      splashColor: Colors.blue[100],
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Container(
        color: Colors.grey[100], 
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.lightBlue[200]!, Colors.lightBlue[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: const AssetImage('assets/images/finance_icon.png'),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Menu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (user != null)
                          Text(
                            user.email ?? "Welcome!",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildListTile(context, Icons.home, "Home", () => _navigate(context, const HomePage())),
            _buildListTile(context, Icons.person, "Profile", () => _navigate(context, ProfileScreen())),
            _buildListTile(
              context,
              Icons.attach_money,
              "Expenses",
              () {
                if (user != null) _navigate(context, MoneyScreen(uid: user.uid));
              },
            ),
            _buildListTile(context, Icons.flag, "Goals", () => _navigate(context, GoalsScreen())),
            _buildListTile(context, Icons.group, "Friends", () => _navigate(context, FriendsScreen())),
            _buildListTile(context, Icons.message, "Messages", () => _navigate(context, MessagesScreen())),
            _buildListTile(context, Icons.settings, "Settings", () => _navigate(context, SettingsScreen())),
            const Divider(color: Colors.grey, indent: 20, endIndent: 20),
            _buildListTile(
              context,
              Icons.exit_to_app,
              "Sign Out",
              () async {
                await FirebaseAuth.instance.signOut();
                exit(0);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
