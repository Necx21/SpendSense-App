import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/transaction_model.dart';
import 'providers/transaction_provider.dart';
import 'main_wrapper.dart'; 
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart';
import 'pages/auth_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    await _initializeFirebaseSafely();

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BudgetLimitAdapter());
    }

    await Future.wait([
      Hive.openBox<Transaction>('transactions').timeout(const Duration(seconds: 10)),
      Hive.openBox('settings').timeout(const Duration(seconds: 10)),
      Hive.openBox<BudgetLimit>('budgetBox').timeout(const Duration(seconds: 10)),
      Hive.openBox('budgets').timeout(const Duration(seconds: 10)),
      Hive.openBox('categoriesBox').timeout(const Duration(seconds: 10)),
      Hive.openBox('user').timeout(const Duration(seconds: 10)),
    ]);
  } catch (e) {
    startupError = e.toString();
  }

  runApp(AppBootstrap(startupError: startupError));
}

Future<void> _initializeFirebaseSafely() async {
  if (Firebase.apps.isNotEmpty) {
    Firebase.app();
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 20));
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      Firebase.app();
      return;
    }
    rethrow;
  }
}

class AppBootstrap extends StatelessWidget {
  final String? startupError;
  const AppBootstrap({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'App failed to start',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    startupError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TransactionProvider()..loadSettings()..loadTransactions(),
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<TransactionProvider, bool>(
      selector: (_, provider) => provider.isDarkMode,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SpendSense',
          
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _AppLoadingScreen();
              }
              if (snapshot.hasError) {
                return _StartupStatusScreen(
                  title: 'Authentication failed',
                  message: snapshot.error.toString(),
                );
              }
              if (snapshot.hasData) {
                return const MainWrapper();
              }
              return const AuthPage();
            },
          ),
          routes: {
            '/home': (context) => const MainWrapper(),
          },
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: const Color(0xFF748D74),
            scaffoldBackgroundColor: const Color(0xFFF8F9F8),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF748D74),
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
        );
      },
      );
    }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F9F8),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF748D74)),
            SizedBox(height: 14),
            Text(
              'Loading SpendSense...',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupStatusScreen extends StatelessWidget {
  final String title;
  final String message;
  const _StartupStatusScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
