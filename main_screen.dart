import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spend_sense_/pages/budget_page.dart';
import 'package:spend_sense_/pages/category_page.dart';
import 'package:spend_sense_/pages/home_page.dart';
import 'package:spend_sense_/pages/analysis_page.dart'; 
import '../widgets/app_drawer.dart';
import 'pages/profile_page.dart';
import '../providers/transaction_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

 static const List<Widget> _pages = [
    HomePage(),
    AnalysisPage(),
    BudgetPage(),
    CategoryPage(),
  ];
 static const List<String> _titles = ["SpendSense", "Analysis", "Budget", "Categories"];
  void onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
        actions: [
          GestureDetector( 
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: Selector<TransactionProvider, String?>(
                selector: (_, p) => p.profileImagePath,
                builder: (context, path, _) {
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: path != null ? FileImage(File(path)) : null,
                    child: path == null 
                        ? const Icon(Icons.person, color: Colors.white, size: 20) 
                        : null,
                  );
                }
              ),
            )
          )
        ],
      ),
     body: IndexedStack(index: _selectedIndex, children: _pages,), 
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromARGB(255, 223, 67, 152),
        unselectedItemColor: Colors.grey,
        onTap: onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: "Analysis"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: "Budget"),
          BottomNavigationBarItem(icon: Icon(Icons.category_rounded), label: "Category"),
        ],
      ),
    );
  }
  // 5. Global Add Entry
  void showGlobalAddOverlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 15,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                const BottomSheetHandle(),
                const Text("Add New Transaction", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const Text("Add New Transaction", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const _AddInput(label: "Amount", icon: Icons.currency_rupee, type: TextInputType.number),
                      const SizedBox(height: 15),
                      const _AddInput(label: "Category", icon: Icons.category),
                      const SizedBox(height: 15),
                      const _AddInput(label: "Title", icon: Icons.title),
                      const SizedBox(height: 25),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF748D74),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Save Transaction", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 40, height: 5,
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
  );
}

class _AddInput extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextInputType type;
  const _AddInput({required this.label, required this.icon, this.type = TextInputType.text});

  @override
  Widget build(BuildContext context) => TextField(
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    ),
  );
}