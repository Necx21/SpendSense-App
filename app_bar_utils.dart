import 'dart:io'; // Import zaruri hai File ke liye
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../providers/transaction_provider.dart';
import '../pages/profile_page.dart';

class AppUtils {
  static PreferredSizeWidget buildCommonAppBar({
    required BuildContext context,
    required String title,
    required TransactionProvider provider,
  }) {
    final supportsLocalImage = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
      ),
      elevation: 0,
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF748D74), 
              backgroundImage: (supportsLocalImage &&
                      provider.profileImagePath != null &&
                      provider.profileImagePath!.isNotEmpty &&
                      File(provider.profileImagePath!).existsSync())
                  ? FileImage(File(provider.profileImagePath!))
                  : null,
              child: (!supportsLocalImage ||
                      provider.profileImagePath == null ||
                      provider.profileImagePath!.isEmpty ||
                      !File(provider.profileImagePath!).existsSync())
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
