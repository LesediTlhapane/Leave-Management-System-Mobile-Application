// login_screen.dart (compact containers)
import 'package:flutter/material.dart';
import 'employee_data.dart';
import 'home_screen.dart';
import 'login_failed_screen.dart'; // ✅ add this

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final idOrNameController = TextEditingController();
  final passwordController = TextEditingController();

  void _goToLoginFailed() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginFailedScreen()),
    );
  }

  void login() {
    final input = idOrNameController.text.trim();
    final password = passwordController.text;

    // quick check: empty fields
    if (input.isEmpty || password.isEmpty) {
      _goToLoginFailed();
      return;
    }

    final user = findEmployee(input); // your helper from employee_data.dart

    // user not found OR password mismatch -> go to failed screen
    if (user == null || user.password != password) {
      _goToLoginFailed();
      return;
    }

    // success -> go home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
    );
  }

  @override
  void dispose() {
    idOrNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ------- compact visual style (matches app) -------
  static const _brandBlue = Color(0xFF3B4D79);
  static const _heading   = Color(0xFF111827);
  static const _muted     = Color(0xFF6B7280);
  static const _border    = Color(0xFFE5E7EB);
  static const _bg        = Color(0xFFF5F7FB);

  InputDecoration _dec(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
      prefixIcon: icon == null ? null : Icon(icon, color: _brandBlue, size: 20),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _brandBlue, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          "Sign In",
          style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // compact header chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD7E3FF)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock_outline, color: _brandBlue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Welcome back! Please sign in.",
                            style: TextStyle(
                              color: _brandBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // compact form card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Employee Login",
                          style: TextStyle(
                            color: _heading,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: _border),
                        const SizedBox(height: 10),

                        TextField(
                          controller: idOrNameController,
                          textInputAction: TextInputAction.next,
                          decoration: _dec("Employee ID", icon: Icons.person_outline),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          onSubmitted: (_) => login(), // enter to submit
                          decoration: _dec("Password", icon: Icons.lock_outline),
                        ),

                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Log In",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
