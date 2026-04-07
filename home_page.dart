import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';
import '../../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../widgets/add_transaction_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _amountController = TextEditingController();
  late final ScrollController _scrollController;
  
  bool _isSearching = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TransactionProvider>();
      provider.fetchNewInsight();
      provider.loadSettings();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void showTransactionSheet([Transaction? tx]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(existingTransaction: tx),
    );
  }
  // --- MATH & DATE HELPERS ---
  double calculateBasicMath(String input) {
    try {
      String cleanedInput = input.replaceAll('x', '*').replaceAll('X', '*').replaceAll('%', '/100').trim();
      if (cleanedInput.isEmpty) return 0.0;
      Parser p = Parser();
      Expression exp = p.parse(cleanedInput);
      return exp.evaluate(EvaluationType.REAL, ContextModel()).toDouble();
    } catch (e) {
      return double.tryParse(input) ?? 0.0;
    }
  }
  // --- DATE PICKER ---
  void _presentDatePicker(StateSetter setModalState) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setModalState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
    );
  }
  
  // --- EDIT EXPENSE OVERLAY ---
  void _openEditOverlay(Transaction transaction) {
    _amountController.text = transaction.amount.toStringAsFixed(2);
    _selectedDate = transaction.date;

    TimeOfDay selectedTime = TimeOfDay(hour: transaction.date.hour, minute: transaction.date.minute);
    
    _selectedCategory = transaction.category;
    bool isIncomeLocal = transaction.isIncome;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only( 
              bottom: MediaQuery.of(ctx).viewInsets.bottom, 
              left: 20, right: 20, top: 20
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 15),
                  const Text("Edit Transaction", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildAddTransactionUI(
                    setModalState, 
                    isIncomeLocal, 
                    (val) => setModalState(() => isIncomeLocal = val), 
                    selectedTime, 
                    (newVal) => setModalState(() => selectedTime = newVal),
                    true, 
                    transaction
                  ),
                  const SizedBox(height: 10),
                  // Delete Button
                  TextButton.icon(
                    onPressed: () async {
                      final provider = Provider.of<TransactionProvider>(context, listen: false);
                      await provider.deleteTransaction(transaction);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text("Delete Transaction", style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  // --- BUILD METHOD ---
  @override
Widget build(BuildContext context) {
  final provider = context.watch<TransactionProvider>();

  return SafeArea(
    child: CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 1. TOP SECTION 
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Keep Grinding!", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(provider.userName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInsightChip(provider)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildBalanceCard(provider),
                const SizedBox(height: 20), 
                if (provider.dateFilter != "All")
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Center(
                    child: Chip(
                      label: Text(
                        DateFormat('dd MMMM yyyy').format(provider.focusedDate),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.teal.withOpacity(0.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. STICKY HEADER SECTION (Stays at the top)
        SliverPersistentHeader(
          pinned: true, 
          delegate: _StickyHeaderDelegate(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildSearchRow(provider), 
            ),
          ),
        ),

        // 3. TRANSACTION LIST
        provider.filteredTransactions.isEmpty 
        ? const SliverFillRemaining(child: Center(child: Text("No transactions yet!")))
        : SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tx = provider.filteredTransactions[index];
                  return buildTransactionItem(tx, provider);
                },
                childCount: provider.filteredTransactions.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    ),
  );
}

  // --- UI COMPONENTS ---
  Widget _buildAddTransactionUI(
    StateSetter setModalState, 
    bool isIncomeLocal, 
    ValueChanged<bool> setIncome, 
    TimeOfDay selectedTime, 
    ValueChanged<TimeOfDay> setTime, 
    bool isEditing, Transaction? existingTx) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _presentDatePicker(setModalState),
                icon: const Icon(Icons.calendar_month),
                label: Text(DateFormat('dd MMM').format(_selectedDate)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickTime(selectedTime);
                  if (picked != null) setTime(picked);
                },
                icon: const Icon(Icons.access_time),
                label: Text(selectedTime.format(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Amount",
            prefixIcon: const Icon(Icons.currency_rupee),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),

        
        const SizedBox(height: 15),
        _buildCategoryDropdown(
          Provider.of<TransactionProvider>(context, listen: false),
          setModalState,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  !isIncomeLocal ? Colors.red : Colors.grey.shade300,
                ),
                onPressed: () => setIncome(false),
                child: const Text("Expense"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isIncomeLocal ? Colors.green : Colors.grey.shade300,
              ),
              onPressed: () => setIncome(true),
              child: const Text("Income"),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: isIncomeLocal ? Colors.green : Colors.black,
        ),
        onPressed: () {
          final amount = calculateBasicMath(_amountController.text);
          if (amount <= 0) return;
          final finalDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
          if (isEditing && existingTx != null) {
            existingTx
            ..amount = amount
            ..date = finalDate
            ..category = _selectedCategory
            ..isIncome = isIncomeLocal;
            Provider.of<TransactionProvider>(context, listen: false)
              .updateTransaction(existingTx);
          } else {
              Provider.of<TransactionProvider>(context, listen: false)
              .addTransaction(
                Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  amount: amount,
                  date: finalDate,
                  category: _selectedCategory,
                  isIncome: isIncomeLocal, title: '',
                ),
              );
            }
            Navigator.pop(context);
        },
        child: Text(
          isEditing ? "Update" : "Save",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      ],
    );
 }

  // --- INSIGHT CHIP ---
  Widget _buildInsightChip(TransactionProvider provider) {
    return GestureDetector(
      onTap: () => _showInsightPopup(provider.dynamicInsight), 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb, size: 13, color: Colors.orange),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                provider.dynamicInsight,
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- INSIGHT POPUP ---
  void _showInsightPopup(String insight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.orange),
            SizedBox(width: 6),
            Text("Insights"),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            insight,
            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it!", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  // --- SEARCH ROW ---
  Widget _buildSearchRow(TransactionProvider provider) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isSearching 
      ? TextField(
          key: const ValueKey(1),
          autofocus: true,
          onChanged: (val) => provider.setSearchQuery(val),
          decoration: InputDecoration(
            hintText: "Search note...",
            prefixIcon: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
              setState(() => _isSearching = false);
              provider.setSearchQuery("");
            }),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
      )
      : Row(
          key: const ValueKey(2),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 2. SEARCH ICON
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
            // 1. LEFT ARROW
            IconButton( 
              icon: const Icon(Icons.arrow_back_ios_new_rounded, 
              size: 18
              ), 
              onPressed: () => provider.moveDateWindow(-1), 
            ),
            // 3. CENTER TITLE (Transaction Text)
            const Expanded(
              child: Text(
                "Transactions",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey),
              ),
            ),
            // 5. RIGHT ARROW
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: () => provider.moveDateWindow(1),
            ),
            // 4. FILTER ICON
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.teal),
              onPressed: () => _showFilterOptions(context)
            ),
          ],
        ),
    );
  }

  // --- BALANCE CARD ---
  Widget _buildBalanceCard(TransactionProvider provider) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF748D74), Color(0xFFA7BC91)]), 
        borderRadius: BorderRadius.circular(30)
      ),
      child: Column(children: [
        const Text("Current Balance", style: TextStyle(color: Colors.white70)),
        Text(
          "${provider.currencySymbol}${provider.totalBalance.toStringAsFixed(2)}", 
          style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildStatItem("Income", provider.totalIncome, Colors.greenAccent, provider.currencySymbol),
          _buildStatItem("Expense", provider.totalExpense, Colors.redAccent, provider.currencySymbol),
        ]),
      ])
    );
  }

  //---Balance Stats---
  Widget _buildStatItem(String label, double amount, Color color, String symbol) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70)), 
      Text("$symbol${amount.toStringAsFixed(0)}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18))
    ]);
  }

  // --- TRANSACTION ITEM ---
  Widget buildTransactionItem(Transaction tx, TransactionProvider provider) {
    final meta = _buildTransactionMeta(tx, context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12), elevation: 0, 
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.black.withOpacity(0.05))),
      child: ListTile(
        onTap: () => _openEditOverlay(tx),
        leading: CircleAvatar(
          backgroundColor: tx.isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          child: Icon(tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: tx.isIncome ? Colors.green : Colors.red),
        ),
        title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(meta),
        trailing: Text(
          "${provider.currencySymbol}${tx.amount.toStringAsFixed(2)}", 
          style: TextStyle(fontWeight: FontWeight.bold, color: tx.isIncome ? Colors.green : Colors.redAccent)
        ),
      ),
    );
  }

  String _buildTransactionMeta(Transaction tx, BuildContext context) {
    try {
      final day = DateFormat('dd MMM').format(tx.date);
      final time = TimeOfDay.fromDateTime(tx.date).format(context);
      return "${tx.category} - $day, $time";
    } catch (_) {
      return tx.category;
    }
  }

  // --- TOGGLE BUTTON ---
  Widget buildToggle(Function setModalState, String label, bool isActive, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setModalState(onTap),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isActive ? color : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  // --- DROPDOWNS & MODALS ---
  Widget _buildCategoryDropdown(TransactionProvider provider, StateSetter setModalState) {
  final savedCategories = provider.categories;
  bool categoryExists = savedCategories.any((cat) => cat['name'] == _selectedCategory);
  if (!categoryExists && savedCategories.isNotEmpty) {
    _selectedCategory = savedCategories.first['name'];
  }
  return DropdownButtonFormField<String>(
    initialValue: _selectedCategory,
    decoration: InputDecoration(
      labelText: "Category",
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      prefixIcon: const Icon(Icons.category_outlined),
    ),
    items: savedCategories.map((cat) {
      return DropdownMenuItem<String>(
        value: cat['name'], 
        child: Row(
          children: [
            Text(cat['icon'] ?? '\u{1F4E6}'),
            const SizedBox(width: 10),
            Text(cat['name']), 
          ],
        ),
      );
    }).toList(),
    onChanged: (val) {
      if (val != null) {
        setModalState(() {
          _selectedCategory = val;
        });
      }
    },
  );
}

  void _showFilterOptions(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    showModalBottomSheet(
      context: context, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          const Padding(padding: EdgeInsets.all(16.0), child: Text("Filter by Period", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ...['All', 'Daily', 'Weekly', 'Monthly', 'Quarterly'].map((filter) => ListTile(
            title: Text(filter), 
            trailing: provider.dateFilter == filter ? const Icon(Icons.check, color: Colors.green) : null, 
            onTap: () { 
              provider.updateDateFilter(filter); 
              Navigator.pop(context); 
            }
          )),
        ]
      )
    );
  }
}

 // --- STICKY HEADER DELEGATE ---
  class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 70.0; 
  @override
  double get maxExtent => 70.0; 

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, 
      alignment: Alignment.center,
      child: child,
    );
  }
  

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => true;
  }