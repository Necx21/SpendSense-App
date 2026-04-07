import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  late String id; 

  @HiveField(1)
  late String title;
  
  @HiveField(2)
  late double amount; 
  
  @HiveField(3)
  DateTime date;
  
  @HiveField(4)
  String category;
  
  @HiveField(5)
  bool isIncome;

  @HiveField(6)
  int colorValue; 
  
  @HiveField(7)
  int iconCodePoint;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.isIncome,
    this.colorValue = 0,
    this.iconCodePoint = 0,
  });
}
 @HiveType(typeId: 1) 
  class BudgetLimit extends HiveObject {
    @HiveField(0)
    final String category;
    @HiveField(1)
    double amount;

    BudgetLimit({required this.category, required this.amount});
  }