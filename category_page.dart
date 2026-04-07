import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emojiController = TextEditingController();

  void openAddCategorySheet(TransactionProvider provider) {
    _nameController.clear();
    _emojiController.clear();
    bool isExpense = true; 
    Color selectedColor = Colors.blue;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
        builder: (ctx) => StatefulBuilder( 
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("New Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            // INCOME / EXPENSE SWITCH
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Expense"),
                  selected: isExpense,
                  onSelected: (val) => setModalState(() => isExpense = true),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text("Income"),
                  selected: !isExpense,
                  onSelected: (val) => setModalState(() => isExpense = false),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(controller: _emojiController, decoration: const InputDecoration(labelText: "Emoji Icon")),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Category Name")),
            const SizedBox(height: 15),
            // COLOR PICKER ROW
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.grey, Colors.brown, Colors.white10, Colors.pink].map((color) => GestureDetector(
                  onTap: () => setModalState(() => selectedColor = color),
                  child: CircleAvatar(backgroundColor: color, radius: 15, child: selectedColor == color ? const Icon(Icons.check, size: 15) : null),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                provider.addCategory(
                  _nameController.text.trim(), 
                  _emojiController.text.trim(),
                  color: selectedColor,
                  isExpense: isExpense,
                );
                Navigator.pop(ctx);
              },
              child: const Text("Save Category"),
            ),
          ],
        ),
      ),
    ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final categories = provider.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Categories"),
        backgroundColor: const Color(0xFF748D74),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => openAddCategorySheet(provider),
          ),
        ],
      ),  
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: categories.map((cat) {
            return GestureDetector(
              onLongPress: () async {
               final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                  title: const Text("Delete Category?"),
                  content: Text(
                    "Deleting '${cat['name']}' will permanently remove this category and all its related records (transactions and budgets) from local database and cloud backup.",
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true), 
                      child: const Text("Delete", style: TextStyle(color: Colors.red))
                    ),
                  ],
                ),
               );
               if (shouldDelete != true) return;

               final result = await provider.deleteCategoryAndRelatedData(
                 cat['name'].toString(),
               );
               if (!mounted) return;
               ScaffoldMessenger.of(this.context).showSnackBar(
                 SnackBar(
                   content: Text(
                     "Deleted '${cat['name']}' | "
                     "${result['transactions'] ?? 0} transactions, "
                     "${result['budgets'] ?? 0} budgets removed.",
                   ),
                 ),
               );
              },
              child: _categoryCard(
                icon: cat["icon"],
                name: cat["name"],
                color: cat["color"] as Color,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _categoryCard({required String icon, required String name, required Color color}) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.15),
            child: Text(icon, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
