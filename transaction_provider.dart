import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:spend_sense_/models/category_model.dart';
import '../models/transaction_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' hide Transaction;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class TransactionProvider with ChangeNotifier {
  static const String _realtimeDbUrl =
      'https://spendsense-23an-default-rtdb.asia-southeast1.firebasedatabase.app';
  Map<String, double> _categoryBudgets = {};
  Box<Transaction>? get _box => Hive.isBoxOpen('transactions') ? Hive.box<Transaction>('transactions') : null;
    Box get _budgetBox => Hive.box('budgets');
  StreamSubscription<User?>? _authSubscription;
  bool _isSyncingFromFirebase = false;
  int _syncNoticeId = 0;
  String _syncNoticeMessage = '';
  bool _syncNoticeIsError = false;
  DateTime _lastSyncNoticeAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastSyncedAt;
  bool _isSyncInProgress = false;
    
  // --- USER STATE ---
  bool _isDarkMode = false;
  List<BudgetLimit> _budgets = [];
  String _userName = "User";
  String? _profileImagePath;
  String _currencySymbol = '\u20B9';
  final ThemeMode _themeMode = ThemeMode.system;
  String _searchQuery = "";
  String _dynamicInsight = "Loading money insight..."; 
  String _dateFilter = "All"; 
  DateTime _focusedDate = DateTime.now();
  List<Transaction> _transactions = [];

  // Getters
  List<BudgetLimit> get budgets => _budgets;
  String get searchQuery => _searchQuery;  
  String get dateFilter => _dateFilter;
  bool get isDarkMode => _isDarkMode;
  String get userName => _userName;
  String? get profileImagePath => _profileImagePath;
  String get currencySymbol => _currencySymbol;
  ThemeMode get themeMode => _themeMode;
  String get dynamicInsight => _dynamicInsight;
  DateTime get focusedDate => _focusedDate;
  List<Transaction> get transactions => _transactions;
  double get totalMonthlyBudget => getTotalBudgetForMonth(DateTime.now());
  int get syncNoticeId => _syncNoticeId;
  String get syncNoticeMessage => _syncNoticeMessage;
  bool get syncNoticeIsError => _syncNoticeIsError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isSyncInProgress => _isSyncInProgress;
  bool get isCloudSyncEnabled {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }
  
  double getBudgetFor(String categoryName) =>
      getBudgetForMonth(categoryName, DateTime.now());
  DatabaseReference? get _userDbRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return null;
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _realtimeDbUrl,
    ).ref('users/${user.uid}');
  }

  void _emitSyncNotice(String message, {bool isError = false, bool force = false}) {
    if (!force && !isError) {
      final elapsed = DateTime.now().difference(_lastSyncNoticeAt);
      if (elapsed < const Duration(seconds: 3)) return;
    }
    _lastSyncNoticeAt = DateTime.now();
    _syncNoticeMessage = message;
    _syncNoticeIsError = isError;
    _syncNoticeId++;
    notifyListeners();
  }

  Map<String, dynamic> _transactionToMap(Transaction tx) {
    return {
      'id': tx.id,
      'title': tx.title,
      'amount': tx.amount,
      'date': tx.date.toIso8601String(),
      'category': tx.category,
      'isIncome': tx.isIncome,
      'colorValue': tx.colorValue,
      'iconCodePoint': tx.iconCodePoint,
    };
  }

  Transaction _transactionFromMap(String key, Map<dynamic, dynamic> raw) {
    final dateRaw = raw['date']?.toString() ?? '';
    final parsedDate = DateTime.tryParse(dateRaw) ?? DateTime.now();
    return Transaction(
      id: (raw['id']?.toString().isNotEmpty ?? false)
          ? raw['id'].toString()
          : key,
      title: (raw['title'] ?? '').toString(),
      amount: (raw['amount'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate,
      category: (raw['category'] ?? 'Others').toString(),
      isIncome: raw['isIncome'] == true,
      colorValue: (raw['colorValue'] as num?)?.toInt() ?? 0,
      iconCodePoint: (raw['iconCodePoint'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _categoryToMap(Map<String, dynamic> category) {
    final colorRaw = category['color'];
    final colorValue = colorRaw is Color
        ? colorRaw.toARGB32()
        : (colorRaw is int ? colorRaw : Colors.grey.toARGB32());
    return {
      'name': (category['name'] ?? '').toString(),
      'icon': (category['icon'] ?? '\u{1F4E6}').toString(),
      'isExpense': category['isExpense'] != false,
      'colorValue': colorValue,
    };
  }

  Map<String, dynamic> _categoryFromMap(Map<dynamic, dynamic> raw) {
    final colorValue = (raw['colorValue'] as num?)?.toInt() ??
        (raw['color'] as num?)?.toInt() ??
        Colors.grey.toARGB32();
    return {
      'name': (raw['name'] ?? 'Others').toString(),
      'icon': (raw['icon'] ?? '\u{1F4E6}').toString(),
      'isExpense': raw['isExpense'] != false,
      'color': Color(colorValue),
    };
  }

  void _syncToFirebase() {
    if (_isSyncingFromFirebase) return;
    unawaited(_pushAllDataToFirebase());
  }

  Future<void> _pushAllDataToFirebase({bool forceNotice = false}) async {
    final ref = _userDbRef;
    if (ref == null) return;
    _isSyncInProgress = true;
    notifyListeners();
    try {
      final transactionsMap = {
        for (final tx in _transactions) tx.id: _transactionToMap(tx),
      };
      final categoriesList = _categories.map(_categoryToMap).toList();
      await ref.update({
        'transactions': transactionsMap,
        'budgets': _categoryBudgets,
        'settings': {
          'name': _userName,
          'currency': _currencySymbol,
          'isDarkMode': _isDarkMode,
          'profileImagePath': _profileImagePath ?? '',
        },
        'categories': categoriesList,
      });
      _lastSyncedAt = DateTime.now();
      _emitSyncNotice('Synced to Firebase', force: forceNotice);
    } catch (e) {
      debugPrint('Firebase sync failed: $e');
      _emitSyncNotice(
        _friendlySyncError(e),
        isError: true,
        force: true,
      );
    } finally {
      _isSyncInProgress = false;
      notifyListeners();
    }
  }

  Future<void> syncNow() async {
    if (!isCloudSyncEnabled) {
      _emitSyncNotice('Guest mode: saved locally only', force: true);
      return;
    }
    await _pushAllDataToFirebase(forceNotice: true);
  }

  Future<void> _loadDataFromFirebase() async {
    final ref = _userDbRef;
    if (ref == null) return;
    try {
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value is! Map) {
        await _pushAllDataToFirebase();
        _emitSyncNotice('Cloud backup initialized');
        return;
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      _isSyncingFromFirebase = true;
      bool remoteHadTransactions = false;
      bool remoteHadBudgets = false;

      final txRaw = data['transactions'];
      if (txRaw is Map) {
        remoteHadTransactions = txRaw.isNotEmpty;
        final box = _box;
        if (box != null) {
          await box.clear();
          _transactions.clear();
          for (final entry in txRaw.entries) {
            if (entry.value is Map) {
              final tx = _transactionFromMap(
                entry.key.toString(),
                Map<dynamic, dynamic>.from(entry.value as Map),
              );
              await box.add(tx);
              _transactions.add(tx);
            }
          }
        }
      }

      final budgetsRaw = data['budgets'];
      if (budgetsRaw is Map) {
        remoteHadBudgets = budgetsRaw.isNotEmpty;
        _categoryBudgets = budgetsRaw.map(
          (key, value) => MapEntry(
            key.toString(),
            (value as num?)?.toDouble() ?? 0.0,
          ),
        );
        await _budgetBox.clear();
        for (final entry in _categoryBudgets.entries) {
          await _budgetBox.put(entry.key, entry.value);
        }
      }

      final settingsRaw = data['settings'];
      if (settingsRaw is Map) {
        if (settingsRaw['name'] is String) {
          _userName = settingsRaw['name'];
          Hive.box('settings').put('name', _userName);
        }
        if (settingsRaw['currency'] is String) {
          _currencySymbol = settingsRaw['currency'];
          Hive.box('settings').put('currency', _currencySymbol);
        }
        if (settingsRaw['isDarkMode'] is bool) {
          _isDarkMode = settingsRaw['isDarkMode'];
          Hive.box('settings').put('isDarkMode', _isDarkMode);
        }
      }

      final categoriesRaw = data['categories'];
      if (categoriesRaw is List) {
        final parsed = <Map<String, dynamic>>[];
        for (final item in categoriesRaw) {
          if (item is Map) {
            parsed.add(_categoryFromMap(Map<dynamic, dynamic>.from(item)));
          }
        }
        if (parsed.isNotEmpty) {
          _categories = _normalizedUniqueCategories(parsed);
          _persistCategoriesLocally();
        }
      } else if (categoriesRaw is Map) {
        final parsed = <Map<String, dynamic>>[];
        for (final item in categoriesRaw.values) {
          if (item is Map) {
            parsed.add(_categoryFromMap(Map<dynamic, dynamic>.from(item)));
          }
        }
        if (parsed.isNotEmpty) {
          _categories = _normalizedUniqueCategories(parsed);
          _persistCategoriesLocally();
        }
      }
      if (!remoteHadTransactions && _transactions.isNotEmpty) {
        await _pushAllDataToFirebase();
      } else if (!remoteHadBudgets && _categoryBudgets.isNotEmpty) {
        await _pushAllDataToFirebase();
      }
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      debugPrint('Firebase load failed: $e');
      _emitSyncNotice('Failed to load cloud data', isError: true, force: true);
    } finally {
      _isSyncingFromFirebase = false;
      notifyListeners();
    }
  }

  void _startAuthSyncListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && !user.isAnonymous) {
        unawaited(_loadDataFromFirebase());
      } else if (user != null && user.isAnonymous) {
        _emitSyncNotice('Guest mode: saved locally only', force: true);
      }
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      unawaited(_loadDataFromFirebase());
    }
  }

  String _friendlySyncError(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Sync failed: database rules blocked access';
      }
      if (error.code == 'network-request-failed') {
        return 'Sync failed: check your internet connection';
      }
      return 'Sync failed: ${error.code}';
    }
    return 'Sync failed: unexpected error';
  }
  DateTime _monthOnly(DateTime value) => DateTime(value.year, value.month);

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  String _monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

  String _budgetStorageKey(String categoryName, DateTime month) =>
      '${_monthKey(month)}::$categoryName';

  double getBudgetForMonth(String categoryName, DateTime month) {
    final normalizedMonth = _monthOnly(month);
    final storageKey = _budgetStorageKey(categoryName, normalizedMonth);
    final monthBudget = _categoryBudgets[storageKey];
    if (monthBudget != null) return monthBudget;

    final now = _monthOnly(DateTime.now());
    if (_isSameMonth(normalizedMonth, now)) {
      return _categoryBudgets[categoryName] ?? 0.0;
    }
    return 0.0;
  }

  double getTotalBudgetForMonth(DateTime month) {
    final normalizedMonth = _monthOnly(month);
    final prefix = '${_monthKey(normalizedMonth)}::';
    final seenCategories = <String>{};
    double total = 0.0;

    _categoryBudgets.forEach((key, value) {
      if (key.startsWith(prefix)) {
        total += value;
        seenCategories.add(key.substring(prefix.length));
      }
    });

    final now = _monthOnly(DateTime.now());
    if (_isSameMonth(normalizedMonth, now)) {
      _categoryBudgets.forEach((key, value) {
        final isMonthSpecific = key.contains('::');
        if (!isMonthSpecific && !seenCategories.contains(key)) {
          total += value;
        }
      });
    }
    return total;
  }
  
  // --- MONTHLY CATEGORY TOTAL ---
  double getMonthlyCategoryTotal(String categoryName) {
    return getCategoryTotalForMonth(categoryName, DateTime.now());
  }

  double getCategoryTotalForMonth(String categoryName, DateTime month) {
    final targetMonth = _monthOnly(month);
    return _transactions.where((t) {
      return t.category == categoryName && 
             !t.isIncome && 
             t.date.month == targetMonth.month && 
             t.date.year == targetMonth.year;
    }).fold(0.0, (sum, item) => sum + item.amount);
  }
  // --- TOTAL MONTHLY SPENT ---
  double get totalMonthlySpent {
      return getTotalSpentForMonth(DateTime.now());
  }

  double getTotalSpentForMonth(DateTime month) {
      final targetMonth = _monthOnly(month);
      return _transactions.where((t) {
        return !t.isIncome && t.date.month == targetMonth.month && t.date.year == targetMonth.year;
      }).fold(0.0, (sum, item) => sum + item.amount);
  }
  // --- LOAD BUDGETS FROM HIVE ---
  void _loadBudgets() {
    if (!Hive.isBoxOpen('budgets')) return;
    try {
      final rawData = _budgetBox.toMap();
      _categoryBudgets = rawData.map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Budget load failed: $e');
      _categoryBudgets = {};
    }
  }
  // --- SET BUDGET FOR CATEGORY ---
  void setBudget(String categoryName, double amount) {
    setBudgetForMonth(categoryName, amount, DateTime.now());
  }

  void setBudgetForMonth(String categoryName, double amount, DateTime month) {
    final normalizedMonth = _monthOnly(month);
    final storageKey = _budgetStorageKey(categoryName, normalizedMonth);
    if (_categoryBudgets[storageKey] == amount) return;

    _categoryBudgets[storageKey] = amount;
    _budgetBox.put(storageKey, amount);

    final now = _monthOnly(DateTime.now());
    if (_isSameMonth(normalizedMonth, now)) {
      _categoryBudgets[categoryName] = amount;
      _budgetBox.put(categoryName, amount);
    }
    _syncToFirebase();
    notifyListeners();
  }
  // --- CURRENCY CONVERSION STATE ---
  Map<String, dynamic> _exchangeRates = {'\u20B9': 1.0, '\$': 0.012, '\u20AC': 0.011, '\u00A3': 0.009, '\u00A5': 1.7};

  // --- ANALYSIS LOGIC ---
  Map<String, double> getCategoryDataFiltered({required bool isIncome, required DateTimeRange range}) {
    Map<String, double> data = {};
    final filteredList = transactions.where((tx) {
      final isWithinDate = tx.date.isAfter(range.start.subtract(const Duration(seconds: 1))) && 
      tx.date.isBefore(range.end.add(const Duration(days: 1)));
      return isWithinDate && tx.isIncome == isIncome;
    });
    for (var tx in filteredList) {
      data[tx.category] = (data[tx.category] ?? 0.0) + tx.amount.toDouble();
    }
    return data;
  }
  // --- CHART LOGIC (Home Page) ---
  Map<String, double> getCategoryData() {
    Map<String, double> data = {};
    for (var tx in filteredTransactions) {
      if (!tx.isIncome) {
        data[tx.category] = (data[tx.category] ?? 0.0) + tx.amount.toDouble();
      }
    }
    return data;
  }
  // --- DATE NAVIGATION ---
  void moveDateWindow(int offset) {
    if (_dateFilter == "Daily") {
      _focusedDate = _focusedDate.add(Duration(days: offset));
    } else if (_dateFilter == "Weekly") {
      _focusedDate = _focusedDate.add(Duration(days: offset * 7));
    } else if (_dateFilter == "Monthly") {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + offset, 1);
    } else if (_dateFilter == "Quarterly") {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + (offset * 3), 1);
    } else if (_dateFilter == "Yearly") {
      _focusedDate = DateTime(_focusedDate.year + offset, _focusedDate.month, 1);
    }
    notifyListeners();
  }
  // --- API FETCH ---
  Future<void> fetchNewInsight() async {
    final fallbackInsight = _buildPersonalMoneyInsight();
    try {
      final uri = Uri.https(
        'api.adviceslip.com',
        '/advice/search/money',
        {'_': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          final slips = data['slips'];
          if (slips is List && slips.isNotEmpty) {
            String? bestAdvice;
            for (final slip in slips) {
              if (slip is Map && slip['advice'] is String) {
                final advice = (slip['advice'] as String).trim();
                if (advice.isEmpty) continue;
                bestAdvice ??= advice;
                if (_isMoneyManagementAdvice(advice)) {
                  bestAdvice = advice;
                  break;
                }
              }
            }
            if (bestAdvice != null && bestAdvice.isNotEmpty) {
              _dynamicInsight = bestAdvice;
              notifyListeners();
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Money insight fetch failed: $e");
    }
    _dynamicInsight = fallbackInsight;
    notifyListeners();
  }

  bool _isMoneyManagementAdvice(String advice) {
    final lower = advice.toLowerCase();
    const keywords = [
      'money',
      'budget',
      'save',
      'saving',
      'spend',
      'expense',
      'debt',
      'invest',
      'financial',
      'income',
      'emergency',
    ];
    return keywords.any(lower.contains);
  }

  String _buildPersonalMoneyInsight() {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);

    if (_transactions.isEmpty) {
      return "No transactions yet. Track expenses for 7 days to get personalized money insights.";
    }

    final monthlySpent = getTotalSpentForMonth(now);
    final monthlyBudget = getTotalBudgetForMonth(now);
    final monthlyIncome = _transactions.where((tx) {
      return tx.isIncome &&
          tx.date.month == now.month &&
          tx.date.year == now.year;
    }).fold(0.0, (sum, tx) => sum + tx.amount);

    if (monthlyBudget > 0) {
      final usage = monthlySpent / monthlyBudget;
      if (usage >= 1.0) {
        final over = monthlySpent - monthlyBudget;
        return "You are $_currencySymbol${over.toStringAsFixed(0)} over your $monthName budget. Reduce non-essential spending this week.";
      }
      if (usage >= 0.85) {
        return "You have used ${(usage * 100).toStringAsFixed(0)}% of your $monthName budget. Keep remaining expenses tight.";
      }
    }

    if (monthlyIncome > 0) {
      final savings = monthlyIncome - monthlySpent;
      final savingsRate = (savings / monthlyIncome) * 100;
      if (savings < 0) {
        return "Your expenses are $_currencySymbol${(-savings).toStringAsFixed(0)} above income this month. Cut variable costs to rebalance.";
      }
      if (savingsRate < 20) {
        return "Your savings rate is ${savingsRate.toStringAsFixed(0)}%. Aim for at least 20% by limiting discretionary spends.";
      }
      return "Great work. You are saving ${savingsRate.toStringAsFixed(0)}% of income this month. Keep following your budget plan.";
    }

    final categorySpends = <String, double>{};
    for (final tx in _transactions) {
      if (!tx.isIncome && tx.date.month == now.month && tx.date.year == now.year) {
        categorySpends[tx.category] =
            (categorySpends[tx.category] ?? 0) + tx.amount;
      }
    }
    if (categorySpends.isNotEmpty) {
      final topCategory = categorySpends.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      return "${topCategory.key} is your highest expense in $monthName at $_currencySymbol${topCategory.value.toStringAsFixed(0)}. Set a cap for this category.";
    }

    return "Set monthly category budgets to get better money management insights.";
  }
  // --- CURRENCY RATE FETCH ---
  bool _isFetchingRates = false;
  bool get isFetchingRates => _isFetchingRates;

  Future<void> fetchLatestRates() async {
    if (_isFetchingRates) return;
    _isFetchingRates = true;
    try {
      final response = await http.get(Uri.parse("https://open.er-api.com/v6/latest/INR")); 
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'];
        _exchangeRates = {
          '\u20B9': 1.0,
          "\$": (rates['USD'] as num).toDouble(),
          '\u20AC': (rates['EUR'] as num).toDouble(),
          '\u00A3': (rates['GBP'] as num).toDouble(),
          '\u00A5': (rates['JPY'] as num).toDouble(),
        };
        Hive.box('settings').put('cached_rates', _exchangeRates);
      }
    } catch (e) {
      debugPrint("Currency fetch failed: $e");
    } finally {
     _isFetchingRates = false;
     notifyListeners();
    }
  }
  // --- SETTINGS LOGIC ---
  void loadSettings() {
    var settingsBox = Hive.box('settings');
    _currencySymbol = settingsBox.get('currency', defaultValue: '\u20B9');
    _isDarkMode = settingsBox.get('isDarkMode', defaultValue: false);
    _userName = settingsBox.get('name', defaultValue: 'User');
    final storedImagePath = settingsBox.get('profileImagePath');
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile &&
        storedImagePath is String &&
        storedImagePath.isNotEmpty &&
        File(storedImagePath).existsSync()) {
      _profileImagePath = storedImagePath;
    } else {
      _profileImagePath = null;
      settingsBox.delete('profileImagePath');
    }
    notifyListeners();
  }
  //--currency convertor--
  void updateCurrency(String newSymbol) {
    if (_currencySymbol == newSymbol) return;
    double currentRate = _exchangeRates[_currencySymbol] ?? 1.0;
    double newRate = _exchangeRates[newSymbol] ?? 1.0;
    double factor = newRate / currentRate;

    for (var tx in _transactions) {
        tx.amount = tx.amount.toDouble() * factor;
        tx.save(); 
    }
    _categoryBudgets.updateAll((category, amount) {
      double convertedAmount = amount * factor;
      _budgetBox.put(category, convertedAmount); 
      return convertedAmount;
    });
    Hive.box('settings').put('currency', newSymbol);
    _currencySymbol = newSymbol;
    _syncToFirebase();
    notifyListeners();
  }
  // --- THEME & PROFILE ---
  void toggleTheme(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    Hive.box('settings').put('isDarkMode', value);
    _syncToFirebase();
    notifyListeners();
  }            
  void updateName(String newName) {
    if (_userName == newName) return;
    _userName = newName;
    Hive.box('settings').put('name', newName); 
    _syncToFirebase();
    notifyListeners();
  }
  Future<void> updateProfileImage(String path) async {
    if (path.isEmpty) return;
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (!isMobile) {
      debugPrint('Profile image save is supported on Android/iOS only.');
      return;
    }
    try {
      final sourceFile = File(path);
      if (!await sourceFile.exists()) return;

      final dir = await getApplicationDocumentsDirectory();
      final ext = sourceFile.path.contains('.')
          ? sourceFile.path.substring(sourceFile.path.lastIndexOf('.'))
          : '.jpg';
      final savedImage = File('${dir.path}/profile_image$ext');
      await sourceFile.copy(savedImage.path);

      _profileImagePath = savedImage.path;
      Hive.box('settings').put('profileImagePath', savedImage.path);
      _syncToFirebase();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save profile image: $e');
    }
  }
  // --- FILTER LOGIC ---
  void updateDateFilter(String filter) {
    if (_dateFilter == filter) return;
    _dateFilter = filter;
    _focusedDate = DateTime.now(); 
    notifyListeners();
  }
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  // Financial Getters
  double get totalIncome => filteredTransactions.where((tx) => tx.isIncome).fold(0.0, (sum, item) => sum + item.amount);
  double get totalExpense => filteredTransactions.where((tx) => !tx.isIncome).fold(0.0, (sum, item) => sum + item.amount);
  double get totalBalance => totalIncome - totalExpense;
  // --- DATABASE OPERATIONS ---
   Future<void> addTransaction(Transaction transaction) async {
    final box = _box;
    if(box == null) return;
    await box.add(transaction);
    _transactions.add(transaction);
    await _pushAllDataToFirebase();
    notifyListeners();
  }
  String _categoryNameKey(Object? name) =>
      name?.toString().trim().toLowerCase() ?? '';

  List<Map<String, dynamic>> _defaultCategories() => [
    {'name': 'Food', 'icon': '\u{1F354}', 'color': Colors.red, 'isExpense': true},
    {'name': 'Transport', 'icon': '\u{1F68C}', 'color': Colors.blue, 'isExpense': true},
    {'name': 'Shopping', 'icon': '\u{1F6CD}', 'color': Colors.green, 'isExpense': true},
    {'name': 'Salary', 'icon': '\u{1F4BC}', 'color': Colors.orange, 'isExpense': false},
    {'name': 'Entertainment', 'icon': '\u{1F3AC}', 'color': Colors.purple, 'isExpense': true},
    {'name': 'Health', 'icon': '\u{1F48A}', 'color': Colors.teal, 'isExpense': true},
    {'name': 'Utilities', 'icon': '\u{1F4A1}', 'color': Colors.amber, 'isExpense': true},
    {'name': 'Others', 'icon': '\u{1F4E6}', 'color': Colors.grey, 'isExpense': true},
  ];

  List<Map<String, dynamic>> _normalizedUniqueCategories(
    Iterable<Map<String, dynamic>> rawCategories,
  ) {
    final seen = <String>{};
    final normalized = <Map<String, dynamic>>[];
    for (final raw in rawCategories) {
      final name = (raw['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final key = _categoryNameKey(name);
      if (key.isEmpty || !seen.add(key)) continue;

      final iconRaw = (raw['icon'] ?? '\u{1F4E6}').toString().trim();
      final colorRaw = raw['color'];
      final color = colorRaw is Color
          ? colorRaw
          : Color((raw['colorValue'] as num?)?.toInt() ?? Colors.grey.toARGB32());

      normalized.add({
        'name': name,
        'icon': iconRaw.isEmpty ? '\u{1F4E6}' : iconRaw,
        'color': color,
        'isExpense': raw['isExpense'] != false,
      });
    }
    return normalized.isEmpty ? _defaultCategories() : normalized;
  }

  void _persistCategoriesLocally() {
    if (Hive.isBoxOpen('categoriesBox')) {
      Hive.box('categoriesBox').put('list', _categories);
    }
    if (Hive.isBoxOpen('settings')) {
      Hive.box('settings').put('custom_categories', _categories);
    }
  }

  Future<void> deleteTransaction(Transaction transaction) async {
    final box = _box;
    if(box == null) return;
    final key = transaction.key;
    await box.delete(key);
    _transactions.removeWhere((tx) => tx.key == key);
    await _pushAllDataToFirebase();
    notifyListeners();
  }
  Future<void> updateTransaction(Transaction transaction) async {
    final box = _box;
    if(box == null) return;
    await transaction.save();
    int index = _transactions.indexWhere((tx) => tx.key == transaction.key);
    if (index != -1) {
      _transactions[index] = transaction;
      await _pushAllDataToFirebase();
      notifyListeners();
    }
  }
  // --- CATEGORY OPERATIONS ---
  void addCategory(String name,
   String icon, { 
    Color color =Colors.green, bool isExpense = true}){
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;
    final normalizedIcon = icon.trim().isEmpty ? '\u{1F4E6}' : icon.trim();

    final category = {
      "name": normalizedName,
      "icon": normalizedIcon,
      "color": color,
      "isExpense": isExpense,
    };
    final existingIndex = _categories.indexWhere(
      (c) => _categoryNameKey(c['name']) == _categoryNameKey(normalizedName),
    );
    if (existingIndex >= 0) {
      _categories[existingIndex] = category;
    } else {
      _categories.add(category);
    }
    _categories = _normalizedUniqueCategories(_categories);
    _persistCategoriesLocally();
    _syncToFirebase();
    notifyListeners();
  }
  void loadTransactions() {
    try {
      if (Hive.isBoxOpen('transactions')) {
        _transactions = Hive.box<Transaction>('transactions').values.toList();
      }
    } catch (e) {
      debugPrint('Transaction load failed: $e');
      _transactions = [];
    }
    try {
      if (Hive.isBoxOpen('budgetBox')) {
        _budgets = Hive.box<BudgetLimit>('budgetBox').values.toList();
      }
    } catch (e) {
      debugPrint('Legacy budget load failed: $e');
      _budgets = [];
    }
    notifyListeners();
  }
  TransactionProvider() {
    _loadBudgets();
    _startAuthSyncListener();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
  // --- INITIALIZATION ---
  Future<void> initProvider() async {
    await Future.wait([
    if (!Hive.isBoxOpen('transactions')) await Hive.openBox<Transaction>('transactions'),
    if (!Hive.isBoxOpen('budgetBox')) await Hive.openBox<BudgetLimit>('budgetBox'),
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings'),
    if (!Hive.isBoxOpen('categoriesBox')) await Hive.openBox('categoriesBox'),
    ] as Iterable<Future<dynamic>>);
    loadSettings();
    loadTransactions(); 
    fetchLatestRates();
    fetchNewInsight();
    loadCategories();
  }
  void loadCategories() {
    try {
      var box = Hive.box('categoriesBox');
      final rawList = box.get('list');
      if (rawList is List) {
        final parsed = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is Map) {
            parsed.add(Map<String, dynamic>.from(item));
          }
        }
        _categories = _normalizedUniqueCategories(parsed);
      } else {
        _categories = _normalizedUniqueCategories(_categories);
      }
    } catch (e) {
      debugPrint('Category load failed: $e');
      _categories = _defaultCategories();
    }
    _persistCategoriesLocally();
    notifyListeners();
  }
  Future<Map<String, int>> deleteCategoryAndRelatedData(String categoryName) async {
    final name = categoryName.trim();
    if (name.isEmpty) {
      return {'transactions': 0, 'budgets': 0};
    }

    int transactionCount = 0;
    int budgetCount = 0;

    final txBox = _box;
    if (txBox != null) {
      final toDelete = _transactions.where((tx) => tx.category == name).toList();
      transactionCount = toDelete.length;
      for (final tx in toDelete) {
        final key = tx.key;
        if (key != null) {
          await txBox.delete(key);
        }
      }
      _transactions.removeWhere((tx) => tx.category == name);
    }

    final budgetKeysToDelete = _categoryBudgets.keys
        .where((key) => key == name || key.endsWith('::$name'))
        .toList();
    budgetCount = budgetKeysToDelete.length;
    for (final key in budgetKeysToDelete) {
      _categoryBudgets.remove(key);
      await _budgetBox.delete(key);
    }

    if (Hive.isBoxOpen('budgetBox')) {
      final legacyBudgetBox = Hive.box<BudgetLimit>('budgetBox');
      for (int i = _budgets.length - 1; i >= 0; i--) {
        if (_budgets[i].category == name) {
          _budgets.removeAt(i);
          await legacyBudgetBox.deleteAt(i);
        }
      }
    }

    _categories.removeWhere((c) => c['name'] == name);
    _persistCategoriesLocally();

    await _pushAllDataToFirebase(forceNotice: true);
    notifyListeners();

    return {
      'transactions': transactionCount,
      'budgets': budgetCount,
    };
  }
  void removeCategory(Map<String, dynamic> category) {
    _categories.remove(category);
    _persistCategoriesLocally();
    _syncToFirebase();
    notifyListeners();
  }
  // --- FILTERED LIST ---
List<Transaction> get filteredTransactions {
    if (_transactions.isEmpty) return [];
    
    // Sort logic handled once
    Iterable<Transaction> list = _transactions.reversed;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((tx) => 
        tx.title.toLowerCase().contains(query) ||
        tx.category.toLowerCase().contains(query)
      );
    }
   if (_dateFilter == "All") return list.toList();

    return list.where((tx) {
      switch (_dateFilter) {
        case "Daily":
          return tx.date.day == _focusedDate.day && tx.date.month == _focusedDate.month && tx.date.year == _focusedDate.year;
        case "Weekly":
          final startOfWeek = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          return tx.date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && tx.date.isBefore(endOfWeek.add(const Duration(days: 1)));
        case "Monthly":
          return tx.date.month == _focusedDate.month && tx.date.year == _focusedDate.year;
        default:
          return true;
      }
    }).toList();
  }

  Color getColor(int index) {
    const colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.cyan, Colors.amber, Colors.teal, Colors.indigo, Colors.pink];
    return colors[index % colors.length];
  }

  // --- EXPORT FEATURE ---
  Future<void> exportTransactionsToCSV() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/transactions_export.csv";
    final file = File(path);
    
    final StringBuffer csvBuffer = StringBuffer("Date,Title,Amount,Category,Type\n");
    for (var tx in _transactions) {
      csvBuffer.writeln("${DateFormat('yyyy-MM-dd').format(tx.date)},${tx.title},${tx.amount},${tx.category},${tx.isIncome ? 'Income' : 'Expense'}");
    }
    
    await file.writeAsString(csvBuffer.toString());
    await Share.shareXFiles([XFile(path)], text: 'My Transactions CSV Export');
  }

  Future<void> exportTransactionsToPDF() async {
    String content = "TRANSACTION REPORT\n\n";
    for (var tx in _box!.values) {
      content += "${DateFormat('dd/MM/yy').format(tx.date)} | ${tx.title} | ${tx.isIncome ? '+' : '-'}${tx.amount}\n";
    }
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/report.txt";
    final file = File(path);
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(path)], text: 'Financial Report');
  }

  List<Map<String, dynamic>> _categories =[
    {'name': 'Food', 'icon': '\u{1F354}', 'color': Colors.red, 'isExpense': true},
    {'name': 'Transport', 'icon': '\u{1F68C}', 'color': Colors.blue, 'isExpense': true},
    {'name': 'Shopping', 'icon': '\u{1F6CD}', 'color': Colors.green, 'isExpense': true},
    {'name': 'Salary', 'icon': '\u{1F4BC}', 'color': Colors.orange, 'isExpense': false},
    {'name': 'Entertainment', 'icon': '\u{1F3AC}', 'color': Colors.purple, 'isExpense': true},
    {'name': 'Health', 'icon': '\u{1F48A}', 'color': Colors.teal, 'isExpense': true},
    {'name': 'Utilities', 'icon': '\u{1F4A1}', 'color': Colors.amber, 'isExpense': true},
    {'name': 'Others', 'icon': '\u{1F4E6}', 'color': Colors.grey, 'isExpense': true},
  ];

  List<Map<String, dynamic>> get categories => _categories;

Future<void> resetAllData() async {
    await _box?.clear();
    await Hive.box('settings').clear();
    await Hive.box('budgets').clear();
    _transactions.clear();
    _currencySymbol = '\u20B9';
    _userName = "User";
    _profileImagePath = null;
    _isDarkMode = false;
    await _pushAllDataToFirebase();
    notifyListeners();
  }

  // --- IMPORT FEATURE ---
  Future<void> importFromCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
       type: FileType.custom,
       allowedExtensions: ['csv'],
     );

      if (result != null) {
       File file = File(result.files.single.path!);
       final input = await file.readAsLines();

       for (var i = 1; i < input.length; i++) {
          final row = input[i].split(',');
         if (row.length >= 6) {
           DateTime parsedDate;
           try {
             parsedDate = DateFormat("MMM dd, yyyy hh:mm a").parse(row[0].replaceAll('"', ''));
           } catch (e) {
             parsedDate = DateTime.now(); 
           }  

           final newTx = Transaction(
             id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
             title: row[5].isEmpty ? row[3] : row[5], 
              amount: double.tryParse(row[2]) ?? 0.0,
             date: parsedDate,
              category: row[3], 
              isIncome: row[1].contains('Income'), 
            );
          
            await addTransaction(newTx);
          }
        }
        notifyListeners();
        debugPrint("Import Successful!");
      }
    } catch (e) {
       debugPrint("Import Error: $e");
      }
  }

  double getCategoryTotal(String category, bool isIncome) {
    double total = 0.0;
    for (var tx in filteredTransactions) {
      if (tx.category == category && tx.isIncome == isIncome) {
        total += tx.amount.toDouble();
      }
    }
    return total;
  }
  
  void updateBudget(String category, double newAmount) {
    final box = Hive.box<BudgetLimit>('budgetBox');
    final index = _budgets.indexWhere((b) => b.category == category);

    if (index != -1) {
      _budgets[index].amount = newAmount;
      box.putAt(index, _budgets[index]);
    } else {
      final newBudget = BudgetLimit(category: category, amount: newAmount);
      _budgets.add(newBudget);
      box.add(newBudget);
    }
    notifyListeners();
  }
  
  double getSpentAmountForCategory(String category) {
    return getCategoryTotalForMonth(category, DateTime.now());
  }

  bool isCategorySafeToDelete(String categoryName) {
    return _transactions.every((tx) => tx.category != categoryName);
  }
  Future<void> toggleCategoryStatus(CategoryItem category) async {
    category.isActive = !category.isActive;
    await category.save();
    notifyListeners();
  }  
  bool categoryExists(String name, bool isExpense) {
    return _categories.any((c) => 
      c['name'].toString().toLowerCase() == name.toLowerCase() && 
      (c['isExpense'] ?? true) == isExpense 
    );
  }


  Widget buildVisualPickers(StateSetter setModalState, CategoryItem tempCategory) {
    final List<int> presetIcons = [Icons.food_bank.codePoint, Icons.shopping_cart.codePoint, Icons.home.codePoint, Icons.directions_car.codePoint];
    final List<Color> presetColors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple];

    return Column(
      children: [
        const Text("Select Icon"),
       Wrap(
          children: presetIcons.map((code) => IconButton(
            icon: Icon(IconData(code, fontFamily: 'MaterialIcons'), 
            color: tempCategory.iconCode == code ? Colors.blue : Colors.grey),
            onPressed: () => setModalState(() => tempCategory.iconCode = code),
         )).toList(),
        ),
        const Text("Select Color"),
       Wrap(
         children: presetColors.map((color) => GestureDetector(
           onTap: () => setModalState(() => tempCategory.colorValue = color.value),
           child: CircleAvatar(backgroundColor: color, radius: 15, 
             child: tempCategory.colorValue == color.value ? const Icon(Icons.check, size: 15) : null),
         )).toList(),
       ),
      ],
    );
  }
}
