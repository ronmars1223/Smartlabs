import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileEditScreen extends StatelessWidget {
  final User user;

  const ProfileEditScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final displayNameController = TextEditingController(text: user.displayName);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: displayNameController,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await user.updateDisplayName(displayNameController.text.trim());
                await user.reload();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated')),
                );
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
