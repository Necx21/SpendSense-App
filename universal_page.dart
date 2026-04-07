import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../pages/profile_page.dart';

class UniversalPage extends StatefulWidget {
  final Widget child;
  final String title;
  final VoidCallback onFabPressed;
  final bool isHomePage; // Special check for Home Page layout

  const UniversalPage({
    super.key,
    required this.child,
    required this.title,
    required this.onFabPressed,
    this.isHomePage = false,
  });

  @override
  State<UniversalPage> createState() => _UniversalPageState();
}

class _UniversalPageState extends State<UniversalPage> {
  bool _isFabVisible = true;
  Timer? _hideTimer;

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isFabVisible) setState(() => _isFabVisible = false);
    });
  }

  void _handleInteraction() {
    if (!_isFabVisible) setState(() => _isFabVisible = true);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);

    return Scaffold(
      // --- THE SPENDSENSE MENU (DRAWER) ---
      drawer: _buildSpendSenseMenu(context, provider),
      
      floatingActionButton: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _isFabVisible ? 1.0 : 0.0,
        child: FloatingActionButton(
          onPressed: _isFabVisible ? widget.onFabPressed : null,
          backgroundColor: const Color(0xFF748D74),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      
      body: GestureDetector(
        onTap: _handleInteraction,
        behavior: HitTestBehavior.translucent,
        child: NotificationListener<ScrollNotification>(
          onNotification: (scroll) {
            _handleInteraction();
            return false;
          },
          child: SafeArea(
            child: Column(
              children: [
                // --- GLOBAL HEADER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      // 1. Menu Icon
                      Builder(builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_open_rounded),
                       onPressed: () => Scaffold.of(ctx).openDrawer(),
                     )),
      
                    // 2. Simple Title (Center)
                   Expanded(
                      child: Center(
                       child: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                     ),
                    ),
      
                    // 3. Profile Icon (Right)
                    GestureDetector(
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                        child: Padding(
                         padding: const EdgeInsets.only(right: 10),
                         child: CircleAvatar(
                           radius: 16,
                           backgroundImage: (provider.profileImagePath != null) ? FileImage(File(provider.profileImagePath!)) : null,
                           child: (provider.profileImagePath == null) ? const Icon(Icons.person, size: 20) : null,
                         ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpendSenseMenu(BuildContext context, TransactionProvider provider) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF748D74)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white, size: 50),
                  SizedBox(height: 10),
                  Text("SpendSense", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Dark Mode"),
            trailing: Switch(value: false, onChanged: (v) {}), // Integration coming next
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text("Currency"),
            trailing: Text(provider.currencySymbol, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () { /* Show Currency Picker */ },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_download, color: Colors.teal),
            title: const Text("Export to PDF"),
            onTap: () { /* PDF Logic */ },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.orange),
            title: const Text("Export to CSV"),
            onTap: () { /* CSV Logic */ },
          ),
        ],
      ),
    );
  }
}