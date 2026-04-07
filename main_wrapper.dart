import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spend_sense_/providers/transaction_provider.dart';
import 'package:spend_sense_/widgets/add_transaction_sheet.dart';
import 'pages/home_page.dart';
import 'pages/analysis_page.dart';
import 'pages/budget_page.dart';
import 'pages/category_page.dart';
import '../utils/app_bar_utils.dart'; 
import 'widgets/app_drawer.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  int _lastSeenSyncNoticeId = 0;

  final List<Widget> _screens = const [
    HomePage(),
    AnalysisPage(),
    BudgetPage(),
    CategoryPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Efficiently calling fetch without rebuilding wrapper
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchLatestRates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncNoticeId = context.select<TransactionProvider, int>(
      (p) => p.syncNoticeId,
    );
    if (syncNoticeId != 0 && syncNoticeId != _lastSeenSyncNoticeId) {
      _lastSeenSyncNoticeId = syncNoticeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<TransactionProvider>();
        final message = provider.syncNoticeMessage;
        if (message.isEmpty) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: provider.syncNoticeIsError
                  ? Colors.redAccent
                  : Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
      });
    }

    return Scaffold(
      extendBody: true,
      appBar: AppUtils.buildCommonAppBar(
        context: context,
        title: _getAppBarTitle(_currentIndex),
        // Performance fix: context.watch ensures rebuild only when profile changes
        provider: context.watch<TransactionProvider>(),
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildCustomBottomBar(),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return "SpendSense";
      case 1: return "Analysis";
      case 2: return "Monthly Budget";
      case 3: return "Categories";
      default: return "SpendSense";
    }
  }

  Widget _buildCustomBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navIcon(Icons.home_outlined, 0),
          _navIcon(Icons.bar_chart_rounded, 1),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddTransactionSheet(),
              );            
            },
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFEC407A), Color(0xFFAB47BC)],
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
          _navIcon(Icons.account_balance_wallet_outlined, 2),
          _navIcon(Icons.category_outlined, 3),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final bool isSelected = _currentIndex == index;
    return IconButton(
      onPressed: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
        }
      },
      icon: Icon(
        icon,
        size: 26,
        color: isSelected ? Colors.white : Colors.white54,
      ),
    );
  }
}
