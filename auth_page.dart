import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true; 
  bool _isLoading = false;
  bool _isPasswordVisible = false;     
  bool _isConfirmVisible = false;      

  // Validation
  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_isValidEmail(email)) {
      _showSnackBar("Invalid Email!");
      return;
    }

    if (password.length < 8) {
      _showSnackBar("Password Should Contain Atleast 8 alpha-numeric character!");
      return;
    }

    if (!_isLogin && password != _confirmPasswordController.text.trim()) {
      _showSnackBar("Passwords Not Match!");
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      String? result;
      if (_isLogin) {
        result = await _authService.loginUser(email, password);
      } else {
        result = await _authService.registerUser(email, password);
      }

       if (result != "Success") {
      String userFriendlyMessage = "Kuch gadbad ho gayi!";

      if (result != null) {
        final lowerResult = result.toLowerCase();
        if (lowerResult.contains("invalid-credential") ||
            lowerResult.contains("wrong-password") ||
            lowerResult.contains("credential is incorrect") ||
            lowerResult.contains("malformed or has expired")) {
          userFriendlyMessage = "Invalid Email/Password. Check Again!";
        } else if (lowerResult.contains("user-not-found")) {
          userFriendlyMessage = "Unknown User, Register Yourself!";
        } else if (lowerResult.contains("network-request-failed")) {
          userFriendlyMessage = "Check Your Internet and Do it Again!";
        } else if (lowerResult.contains("too-many-requests")) {
          userFriendlyMessage = "Await for 2 Minutes";
        } else {
          userFriendlyMessage = result; 
        }
      }

      _showInfoDialog("Oops!", userFriendlyMessage);
    }
    } catch (e) {
      _showInfoDialog("Error", "Unexpected Error:${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      _showSnackBar("Guest Login Failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showSnackBar("Enter a valid email first.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.sendPasswordReset(email);
      if (result == "Success") {
        _showInfoDialog(
          "Reset Email Sent",
          "Password reset link has been sent to $email",
        );
      } else {
        _showInfoDialog("Reset Failed", result ?? "Unable to send reset email.");
      }
    } catch (e) {
      _showInfoDialog("Reset Failed", "Unexpected Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Okay")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Section
              Container(
                height: 120, width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 20),
              Text(_isLogin ? "Spend Smart\nLive Better" : "Create Account",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                height:1.1)),
              const SizedBox(height: 30),
              
              // Email Field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 15),
              
              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 15),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text("Forgot Password?"),
                  ),
                ),
              if (_isLogin) const SizedBox(height: 5),

              // Confirm Password (Signup only)
              if (!_isLogin) ...[
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmVisible,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 25),
              ],
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF748D74),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isLogin ? "Login" : "Sign Up", style: const TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),

              const SizedBox(height: 15),
              
              // Guest Login Button
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isLoading ? null : _signInAnonymously,
                child: const Text("Try as Guest", style: TextStyle(color: Colors.grey)),
              ),
              
              // Toggle Login/Signup
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "New here? Create account" : "Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
