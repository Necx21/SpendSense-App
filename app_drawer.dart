import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final supportsLocalImage = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Drawer(
      child: Column(
        children: [
          // --- UPPER PHASE: HEADER BOX ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            decoration: const BoxDecoration(color: Color(0xFF748D74)),
            child: Column(
              children: [
                const Text(
                  "SPENDSENSE",
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 2
                  ),
                ),
                const SizedBox(height: 15),
                // Profile & Name in a Transparent Box
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
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
                            ? const Icon(Icons.person, color: Color(0xFF748D74), size: 35)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        provider.userName,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- LOWER PHASE: OPTIONS ---
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. Theme Toggle
                _drawerTile(
                  icon: provider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  title: "Dark Mode",
                  trailing: Switch(
                    activeThumbColor: const Color(0xFF748D74),
                    value: provider.isDarkMode,
                    onChanged: (val) => provider.toggleTheme(val),
                  ),
                ),

                // 2. Currency Selector
                _drawerTile(
                  icon: Icons.currency_exchange,
                  title: "Currency",
                  trailing: Text(
                    provider.currencySymbol,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF748D74)),
                  ),
                  onTap: () => _showCurrencyDialog(context, provider),
                ),

                const Divider(indent: 20, endIndent: 20),

                // 3. Export Options
                _drawerTile(
                  icon: Icons.grid_on_rounded,
                  title: "Export to CSV",
                  onTap: () {
                    Navigator.pop(context);
                    provider.exportTransactionsToCSV();
                  },
                ),
                _drawerTile(
                  icon: Icons.picture_as_pdf_rounded,
                  title: "Export to PDF",
                  onTap: () {
                    Navigator.pop(context);
                    provider.exportTransactionsToPDF();
                  },
                ),
                // 4. IMPORT OPTION (NEW FEATURE)
                _drawerTile(
                  icon: Icons.file_upload_outlined,
                  title: "Import from CSV",
                  onTap: () {
                    Navigator.pop(context); // Drawer close
                    provider.importFromCSV(); // Import logic call
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                // 5. Reset All Data
                _drawerTile(
                  icon: Icons.delete_forever_rounded,
                  title: "Reset All Data",
                  onTap: () {
                    _showResetConfirmation(context, provider);
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                // 6. Logout Option
                _drawerTile(
                  icon: Icons.logout_rounded,
                  title: "Logout",
                  onTap: () => _showLogoutConfirmation(context),
                ),
                const Divider(indent: 20, endIndent: 20),
              ],
            ),
          ),

          // --- FOOTER PHASE: VERSION INFO ---
          const Text("v 1.0.0", style: TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  Widget _drawerTile({
    required IconData icon, 
    required String title, 
    Widget? trailing, 
    VoidCallback? onTap
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4F5F4F)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _showCurrencyDialog(BuildContext context, TransactionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Currency"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['\u20B9', '\$', '\u20AC', '\u00A3', '\u00A5'].map((s) => ListTile(
            title: Text(s, style: const TextStyle(fontSize: 20)),
            onTap: () {
              provider.updateCurrency(s);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }


  void _showResetConfirmation(BuildContext context, TransactionProvider provider) {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: const Text("Reset Data?"),
        content: const Text("Are you sure? All your transaction data and settings will be deleted. This cannot be undone!"),
        actions: [
          TextButton(
           onPressed: () => Navigator.pop(context),
           child: const Text("Cancel"),
          ),
         TextButton(
            onPressed: () async {
             await provider.resetAllData();
             Navigator.pop(context); // Dialog band
             Navigator.pop(context); // Drawer band
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("App data has been reset!")),
             );
           },
           child: const Text("Reset Now", style: TextStyle(color: Colors.red)),
         ),
        ],
      ),
    );
  }
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout from SpendSense?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pop(context); 
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
