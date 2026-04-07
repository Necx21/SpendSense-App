// profile_page.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/transaction_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _pickImage(TransactionProvider provider) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      await provider.updateProfileImage(image.path);
    }
  }

  void _showEditNameDialog(TransactionProvider provider) {
    _nameController.text = provider.userName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Update Name"),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: "Enter your name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              provider.updateName(_nameController.text);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.red),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
  // Logout Confirmation Dialog
  void _showLogoutConfirmation(BuildContext context) {
    final bool isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: Text(isAnonymous 
          ? "WARNING: You are a Guest. Logging out will delete all your data permanently!" 
          : "Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx); 
              await FirebaseAuth.instance.signOut();
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final supportsLocalImage = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final imagePath = provider.profileImagePath ?? '';
    final hasProfileImage =
        supportsLocalImage && imagePath.isNotEmpty && File(imagePath).existsSync();
    final cloudEnabled = provider.isCloudSyncEnabled;
    final lastSyncedAt = provider.lastSyncedAt;
    final lastSyncedText = lastSyncedAt == null
        ? "Not synced yet"
        : DateFormat('dd MMM yyyy, hh:mm a').format(lastSyncedAt);
    final user = FirebaseAuth.instance.currentUser;
    final bool isAnonymous = user?.isAnonymous ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile Settings"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // PROFILE IMAGE
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: hasProfileImage
                        ? FileImage(File(imagePath))
                        : null,
                    child: !hasProfileImage
                        ? const Icon(Icons.person,
                            size: 60, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _pickImage(provider),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.pink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // USER NAME
            Text(
              provider.userName,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _showEditNameDialog(provider),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text("Edit Name"),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cloudEnabled ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cloudEnabled ? Colors.green.shade200 : Colors.orange.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cloudEnabled ? Icons.cloud_done_outlined : Icons.phone_android_outlined,
                        size: 18,
                        color: cloudEnabled ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cloudEnabled ? "Cloud Sync Enabled" : "Local Only (Guest)",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cloudEnabled ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cloudEnabled
                        ? "Last synced: $lastSyncedText"
                        : "Guest mode stores data only on this device.",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (cloudEnabled && !provider.isSyncInProgress)
                          ? () => provider.syncNow()
                          : null,
                      icon: Icon(
                        provider.isSyncInProgress ? Icons.sync : Icons.cloud_upload_outlined,
                        size: 18,
                      ),
                      label: Text(provider.isSyncInProgress ? "Syncing..." : "Sync Now"),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 40),

            // PRIVACY
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ListTile(
                leading:
                    const Icon(Icons.lock_outline, color: Colors.green),
                title: const Text("Privacy Policy"),
                trailing:
                    const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
            ),

            // HELP
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ListTile(
                leading:
                    const Icon(Icons.help_outline, color: Colors.purple),
                title: const Text("Help & Support"),
                trailing:
                    const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
            ),

            //--Account Link--
            if (isAnonymous) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.orange),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          SizedBox(width: 10),
                          Text(
                            "Guest Account",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Your data is stored locally. If you logout or uninstall, your transactions will be lost.",
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        onPressed: () {
                          FirebaseAuth.instance.signOut(); 
                        },
                        child: const Text("Create Permanent Account", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            _drawerTile(
              icon: Icons.logout_rounded,
              title: "Logout",
              onTap: () => _showLogoutConfirmation(context),
            ),
            const SizedBox(height: 10),

            // APP VERSION
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("App Version"),
              trailing: Text("1.0.0"),
            ),
          ],
        ),
      ),
    );
  }
}
