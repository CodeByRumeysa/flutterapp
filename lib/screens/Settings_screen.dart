import 'package:flutter/material.dart';
import 'package:flutter_application_2/settings_provider.dart';
import 'package:provider/provider.dart';
import 'about_screen.dart';
import 'profile_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: settings.isDarkMode,
            onChanged: (value) {
              settings.setDarkMode(value);
            },
          ),

         
          SwitchListTile(
            title: const Text("Notifications"),
            value: settings.notificationsEnabled,
            onChanged: (value) {
              settings.setNotificationsEnabled(value);
            },
          ),

         
          ListTile(
            title: const Text("Change Password"),
            leading: const Icon(Icons.lock),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),

         
          ListTile(
            title: const Text("Profile"),
            leading: const Icon(Icons.person),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen()),
              );
            },
          ),

          
          ListTile(
            title: const Text("About"),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
