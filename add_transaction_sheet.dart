import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

class AddTransactionSheet extends StatefulWidget {
 final Transaction? existingTransaction; 
 const AddTransactionSheet({super.key, this.existingTransaction});
  
  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late final TextEditingController _titleController;
  final ValueNotifier<String> _amountNotifier = ValueNotifier("0");

  String selectedCategory = 'Food'; 
  bool _isIncome = false;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingTransaction?.title ?? "");
    if (widget.existingTransaction != null) {
      _amountNotifier.value = widget.existingTransaction!.amount.toString();
      selectedCategory = widget.existingTransaction!.category;
      _isIncome = widget.existingTransaction!.isIncome;
      _selectedDate = widget.existingTransaction!.date;
      _selectedTime = TimeOfDay(
        hour: widget.existingTransaction!.date.hour,
        minute: widget.existingTransaction!.date.minute,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountNotifier.dispose();
    super.dispose();
  }
  double _calculateMath(String value) {
    if (value.isEmpty || value == "0") return 0.0;
    try {
      String cleaned = value
          .replaceAll('\u00D7', '*')
          .replaceAll('\u00F7', '/')
          .replaceAll('x', '*')
          .replaceAll('X', '*')
          .trim();
      Parser p = Parser();
      Expression exp = p.parse(cleaned);
      double result = exp.evaluate(EvaluationType.REAL, ContextModel());
      return result;
    } catch (e) {
      debugPrint("Math Error: $e");
      return double.tryParse(value) ?? 0.0;
    }
  }

  List<Map<String, dynamic>> _visibleCategories(
    List<Map<String, dynamic>> allCategories,
  ) {
    final expectedIsExpense = !_isIncome;
    final seenNames = <String>{};
    final filtered = <Map<String, dynamic>>[];

    for (final cat in allCategories) {
      final isExpense = cat['isExpense'] != false;
      if (isExpense != expectedIsExpense) continue;

      final name = (cat['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      if (!seenNames.add(name.toLowerCase())) continue;

      filtered.add({
        'name': name,
        'icon': (cat['icon'] ?? '\u{1F4E6}').toString(),
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); 
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.existingTransaction != null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 10,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DragHandle(),

            Text(
              isEditing ? "Edit Transaction" : "Add Transaction",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            // 1. EXPENSE / INCOME TOGGLE (Adaptive Colors)
            Row(
              children: [
                _buildTypeBtn(theme, "EXPENSE", !_isIncome, Colors.redAccent, () => setState(() => _isIncome = false)),
                const SizedBox(width: 10),
                _buildTypeBtn(theme, "INCOME", _isIncome, Colors.green, () => setState(() => _isIncome = true)),
              ],
            ),
            const SizedBox(height: 20),
            
            // 2. NOTE INPUT
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "What was this for",
                filled: true,
                fillColor: theme.cardColor,
                prefixIcon: Icon(Icons.edit, color: theme.iconTheme.color?.withOpacity(0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),

            // 2. CATEGORY SELECTOR
            _buildCategoryDropdown(theme),
            const SizedBox(height: 15),

            // 3. DATE & TIME PICKER
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  final time = await showTimePicker(context: context, initialTime: _selectedTime);
                  if (time != null) {
                    setState(() {
                      _selectedDate = date;
                      _selectedTime = time;
                    });
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "${DateFormat('dd MMM yyyy').format(_selectedDate)}, ${_selectedTime.format(context)}",
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 4. ADAPTIVE AMOUNT DISPLAY 
            ValueListenableBuilder<String>(
              valueListenable: _amountNotifier,
              builder: (context, val, _) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Text('\u20B9', style: TextStyle(color: theme.primaryColor, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 15),

            // 5. NUMBER PAD (Theme Adaptive Buttons)
            _buildNumberPad(theme),
            const SizedBox(height: 20),

            // 6. ACTION BUTTONS
           Row(
              children: [
                Expanded(child: _buildActionBtn(theme, "CANCEL", theme.colorScheme.error.withOpacity(0.1), theme.colorScheme.error, () => Navigator.pop(context))),
                const SizedBox(width: 15),
                Expanded(child: _buildActionBtn(theme, "SAVE", theme.primaryColor, Colors.white, _handleSave)),
              ],
            ),
          ],
        ),
      ),
    );
 
  }

  void _handleSave() {
    final finalAmount = _calculateMath(_amountNotifier.value);
    if (_titleController.text.trim().isEmpty ||
        finalAmount <= 0 ||
        selectedCategory.trim().isEmpty) {
      return;
    }

    final tx = Transaction(
      id: widget.existingTransaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      amount: finalAmount,
      date: _selectedDate,
      category: selectedCategory,
      isIncome: _isIncome,
    );

    context.read<TransactionProvider>().addTransaction(tx);
    Navigator.pop(context);
  }

  Widget _buildCategoryDropdown(ThemeData theme) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final visibleCategories = _visibleCategories(provider.categories);
        final categoryNames = visibleCategories
            .map((cat) => cat['name'] as String)
            .toList();
        final hasValidSelection = categoryNames.contains(selectedCategory);
        final dropdownValue = hasValidSelection
            ? selectedCategory
            : (categoryNames.isNotEmpty ? categoryNames.first : null);

        if (!hasValidSelection &&
            categoryNames.isNotEmpty &&
            selectedCategory != categoryNames.first) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => selectedCategory = categoryNames.first);
          });
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(15)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dropdownValue,
              isExpanded: true,
              hint: Text(_isIncome ? "No income categories" : "No expense categories"),
              items: visibleCategories.map((cat) => DropdownMenuItem(
                value: cat['name'] as String,
                child: Row(
                  children: [
                    Text(cat['icon'] as String),
                    const SizedBox(width: 10),
                    Text(cat['name'] as String),
                  ],
                ),
              )).toList(),
              onChanged: categoryNames.isEmpty
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => selectedCategory = val);
                      }
                    },
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberPad(ThemeData theme) {
    const keys = ['7', '8', '9', '/', '4', '5', '6', '*', '1', '2', '3', '-', 'C', '0', '.', '+', '00', ' ', '<', '='];
    final operatorTextColor = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.primary;
    final operatorBgColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.primary.withOpacity(0.25)
        : theme.colorScheme.primary.withOpacity(0.12);
    final normalTextColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.6,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        final isOp = ['/', '*', '-', '+', '=', 'C', '<'].contains(key);
        final buttonTextColor = key == '='
            ? Colors.white
            : (isOp ? operatorTextColor : normalTextColor);

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: key == '='
                ? theme.primaryColor
                : (isOp ? operatorBgColor : theme.cardColor),
            foregroundColor: buttonTextColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            setState(() {
              if (key == 'C') {
                _amountNotifier.value = "0";
              } else if (key == '<') {
                if (_amountNotifier.value.length > 1) {
                  _amountNotifier.value = _amountNotifier.value.substring(0, _amountNotifier.value.length - 1);
                } else {
                  _amountNotifier.value = "0";
                }
              }
              else if (key == '=') _amountNotifier.value = _calculateMath(_amountNotifier.value).toStringAsFixed(2);
              else _amountNotifier.value = (_amountNotifier.value == "0") ? key : _amountNotifier.value + key;
            });
          },
          child: key == '<' 
            ? Icon(Icons.backspace_outlined, size: 18, color: buttonTextColor)
            : Text(
                key,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: buttonTextColor,
                ),
              ),
        );
      },
    );
  }

Widget _buildTypeBtn(ThemeData theme, String label, bool active, Color activeColor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? activeColor : theme.cardColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: active ? Colors.white : theme.disabledColor, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(ThemeData theme, String label, Color bgColor, Color textColor, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: bgColor, 
        padding: const EdgeInsets.all(16), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
      ),
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
    );
  }
}

double calculateMath(String value) {
  if (value.isEmpty || value == "0") return 0.0;

  try {
    String cleaned = value
        .replaceAll('\u00D7', '*')
        .replaceAll('\u00F7', '/')
        .replaceAll('x', '*')
        .replaceAll('X', '*')
        .trim();
    Parser p = Parser();
    Expression exp = p.parse(cleaned);
    ContextModel cm = ContextModel();
    double result = exp.evaluate(EvaluationType.REAL, cm);
    
    return result;
  } catch (e) {
    debugPrint("Math Error: $e");
    return double.tryParse(value) ?? 0.0;
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 15),
    width: 40, height: 4,
    decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(10)),
  );
}
