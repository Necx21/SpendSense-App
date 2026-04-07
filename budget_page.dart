import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
        1,
      );
    });
  }

  String _monthLabel(DateTime month) => DateFormat('MMMM yyyy').format(month);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final allCategories = provider.categories;
    final month = _selectedMonth;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (provider.isFetchingRates)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: Colors.orange,
                      ),
                    Text(
                      "Track your spending by category",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => _changeMonth(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                            tooltip: "Previous month",
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                _monthLabel(month),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _changeMonth(1),
                            icon: const Icon(Icons.chevron_right_rounded),
                            tooltip: "Next month",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSummaryCard(provider, month),
            ),
            allCategories.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                      child: Text("No budgets set. Add them in Settings."),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(20.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final cat = allCategories[index];
                          final name = cat['name'] as String;
                          final icon = (cat['icon'] as String?) ?? "📦";
                          final color = (cat['color'] as Color?) ?? Colors.teal;
                          final budgetAmt =
                              provider.getBudgetForMonth(name, month);
                          final spentAmt =
                              provider.getCategoryTotalForMonth(name, month);
                          final progressVal =
                              budgetAmt > 0 ? spentAmt / budgetAmt : 0.0;

                          return AnimatedBudgetTile(
                            name: name,
                            icon: icon,
                            color: color,
                            spent: spentAmt,
                            budget: budgetAmt,
                            progress: progressVal,
                            symbol: provider.currencySymbol,
                            onTap: () => _showBudgetDialog(
                              context,
                              provider,
                              name,
                              budgetAmt,
                              month,
                            ),
                          );
                        },
                        childCount: allCategories.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(TransactionProvider provider, DateTime month) {
    final totalBudget = provider.getTotalBudgetForMonth(month);
    final totalSpent = provider.getTotalSpentForMonth(month);
    final left = totalBudget - totalSpent;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF748D74).withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF748D74).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            "${provider.currencySymbol}${left.toStringAsFixed(0)} left",
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF748D74),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${provider.currencySymbol}${totalSpent.toStringAsFixed(0)} spent",
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                "${provider.currencySymbol}${totalBudget.toStringAsFixed(0)} budgeted",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog(
    BuildContext context,
    TransactionProvider provider,
    String category,
    double currentBudget,
    DateTime month,
  ) {
    final controller = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toString() : "",
    );
    final monthLabel = DateFormat('MMM yyyy').format(month);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Set Budget for $category ($monthLabel)"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "0.00",
            prefixText: "${provider.currencySymbol} ",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              final newAmount = double.tryParse(controller.text) ?? 0.0;
              provider.setBudgetForMonth(category, newAmount, month);
              Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class AnimatedBudgetTile extends StatefulWidget {
  final String name;
  final String icon;
  final String symbol;
  final Color color;
  final double spent;
  final double budget;
  final double progress;
  final VoidCallback onTap;

  const AnimatedBudgetTile({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.spent,
    required this.budget,
    required this.progress,
    required this.symbol,
    required this.onTap,
  });

  @override
  State<AnimatedBudgetTile> createState() => _AnimatedBudgetTileState();
}

class _AnimatedBudgetTileState extends State<AnimatedBudgetTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = widget.progress >= 0.8 && widget.progress < 1.0;
    final isOver = widget.progress >= 1.0;
    final remaining = widget.budget - widget.spent;

    return ScaleTransition(
      scale: isOver
          ? Tween(begin: 1.0, end: 1.03).animate(_controller)
          : const AlwaysStoppedAnimation(1.0),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isOver
                        ? Colors.red.withOpacity(0.1)
                        : widget.color.withOpacity(0.1),
                    child: Text(widget.icon),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${widget.symbol}${widget.spent.toStringAsFixed(0)} / "
                          "${widget.symbol}${widget.budget.toStringAsFixed(0)}",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${widget.symbol}${remaining.abs().toStringAsFixed(0)} "
                    "${remaining < 0 ? 'over' : 'left'}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOver
                          ? Colors.red
                          : (isWarning ? Colors.orange : Colors.green[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: widget.progress.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOver
                            ? Colors.red
                            : (isWarning ? Colors.orange : widget.color),
                      ),
                    ),
                  ),
                  if (isOver)
                    Positioned.fill(
                      child: FadeTransition(
                        opacity: _controller,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
