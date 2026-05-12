// lib/login_screen.dart
// LeaveFlow — Beautiful Employee Login Screen

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'employee_data.dart';
import 'home_screen.dart';
import 'login_failed_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _idController       = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure             = true;
  bool _loading             = false;

  late AnimationController _bgController;
  late AnimationController _fadeController;
  late Animation<double>   _fadeAnim;

  // ── brand colours ─────────────────────────────────────────────
  static const _navy   = Color(0xFF1E2D5A);
  static const _blue   = Color(0xFF3B4D79);
  static const _accent = Color(0xFF6C8EF5);
  static const _light  = Color(0xFFEEF2FF);
  static const _muted  = Color(0xFF8A94AD);

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _fadeController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final input    = _idController.text.trim();
    final password = _passwordController.text;

    if (input.isEmpty || password.isEmpty) {
      _goFailed();
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final user = findEmployee(input);
    if (user == null || user.password != password) {
      if (mounted) setState(() => _loading = false);
      _goFailed();
      return;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => HomeScreen(user: user),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _goFailed() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginFailedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Animated gradient background ────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) {
              final t = _bgController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + t * 0.6, -1),
                    end:   Alignment(1, 1 - t * 0.4),
                    colors: const [
                      Color(0xFF0F1A38),
                      Color(0xFF1E2D5A),
                      Color(0xFF2A3F7E),
                      Color(0xFF1A2650),
                    ],
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              );
            },
          ),

          // ── Decorative circles ───────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: _GlowCircle(size: 280, color: _accent.withOpacity(0.12)),
          ),
          Positioned(
            bottom: 80,
            left: -100,
            child: _GlowCircle(size: 340, color: _blue.withOpacity(0.18)),
          ),
          Positioned(
            top: 200,
            left: -40,
            child: _GlowCircle(size: 150, color: _accent.withOpacity(0.07)),
          ),

          // ── Floating orbs ────────────────────────────────────
          ..._buildOrbs(),

          // ── Main content ─────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBrand(),
                        const SizedBox(height: 36),
                        _buildCard(),
                        const SizedBox(height: 24),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Brand logo + name ────────────────────────────────────────
  Widget _buildBrand() {
    return Column(
      children: [
        // Logo container
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Leaf/wave icon
              Icon(
                Icons.waves_rounded,
                color: _accent,
                size: 38,
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6CE5A0),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6CE5A0).withOpacity(0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // LeaveFlow wordmark
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Leave',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Flow',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 34,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6C8EF5),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Tagline pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: const Text(
            'Employee Portal',
            style: TextStyle(
              color: Color(0xFFB4C6FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // ── Login card ───────────────────────────────────────────────
  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: Colors.white.withOpacity(0.04),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF6C8EF5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Sign in to your account',
                        style: TextStyle(
                          color: Color(0xFF8A94AD),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const _Divider(),
              const SizedBox(height: 24),

              // Employee ID field
              _buildLabel('Employee ID'),
              const SizedBox(height: 6),
              _buildField(
                controller: _idController,
                hint: 'e.g. 12345',
                icon: Icons.badge_outlined,
                action: TextInputAction.next,
              ),

              const SizedBox(height: 16),

              // Password field
              _buildLabel('Password'),
              const SizedBox(height: 6),
              _buildField(
                controller: _passwordController,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                action: TextInputAction.done,
                onSubmit: (_) => _login(),
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _muted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),

              const SizedBox(height: 28),

              // Sign in button
              _buildButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFB4C6FF),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmit,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textInputAction: action,
        onSubmitted: onSubmit,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _muted.withOpacity(0.6), fontSize: 14),
          prefixIcon: Icon(icon, color: _muted, size: 18),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildButton() {
    return GestureDetector(
      onTap: _loading ? null : _login,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined,
                color: _muted.withOpacity(0.6), size: 13),
            const SizedBox(width: 5),
            Text(
              'Secured with end-to-end encryption',
              style: TextStyle(
                color: _muted.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '© 2025 LeaveFlow · Employee App v2.0',
          style: TextStyle(
            color: _muted.withOpacity(0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOrbs() {
    return [
      Positioned(
        top: 120,
        right: 30,
        child: AnimatedBuilder(
          animation: _bgController,
          builder: (_, __) {
            final dy = math.sin(_bgController.value * math.pi * 2) * 12;
            return Transform.translate(
              offset: Offset(0, dy),
              child: _MiniOrb(color: _accent.withOpacity(0.25), size: 12),
            );
          },
        ),
      ),
      Positioned(
        top: 350,
        left: 20,
        child: AnimatedBuilder(
          animation: _bgController,
          builder: (_, __) {
            final dy = math.cos(_bgController.value * math.pi * 2) * 10;
            return Transform.translate(
              offset: Offset(0, dy),
              child: _MiniOrb(
                  color: const Color(0xFF6CE5A0).withOpacity(0.2), size: 8),
            );
          },
        ),
      ),
    ];
  }
}

// ── Helper widgets ───────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _MiniOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _MiniOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.white.withOpacity(0.08));
  }
}