import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 2) // Ensure typeId doesn't conflict with Transaction (0) or BudgetLimit (1)
class CategoryItem extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int iconCode; // Store icon as int

  @HiveField(2)
  int colorValue; // Store color as int

  @HiveField(3)
  bool isExpense; // true for Expense, false for Income

  @HiveField(4)
  bool isActive; // For "disabling" rather than deleting

  CategoryItem({
    required this.name,
    required this.iconCode,
    required this.colorValue,
    this.isExpense = true,
    this.isActive = true,
  });
}