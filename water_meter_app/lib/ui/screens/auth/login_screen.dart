import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/auth_provider.dart';
import 'register_screen.dart';
import '../../../main.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController   = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(authProvider.notifier)
          .login(_identifierController.text.trim(), _passwordController.text);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(error ?? 'Login failed. Please try again.')),
            ]),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    }
  }

  // ── pill input decoration ────────────────────────────────────────────────
  static OutlineInputBorder _pillBorder({Color? color, double width = 0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: color != null
            ? BorderSide(color: color, width: width)
            : BorderSide.none,
      );

  static InputDecoration _pill(
    String hint,
    IconData icon, {
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFFB0BEC5), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: _pillBorder(),
        enabledBorder: _pillBorder(),
        focusedBorder:
            _pillBorder(color: AppTheme.primaryBlue, width: 1.5),
        errorBorder: _pillBorder(color: AppTheme.errorRed),
        focusedErrorBorder:
            _pillBorder(color: AppTheme.errorRed, width: 1.5),
      );

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final screenH   = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Gradient background ────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF81D4FA), AppTheme.primaryBlue],
              ),
            ),
          ),

          // ── Top branding ───────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenH * 0.38,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop_rounded,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to your account',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── White card ─────────────────────────────────────────────
          Positioned(
            top: screenH * 0.36,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Card title ──────────────────────────────
                      const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your credentials to continue',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 28),

                      // ── Identifier field ────────────────────────
                      TextFormField(
                        controller: _identifierController,
                        decoration: _pill(
                          'Phone or Account Number',
                          Icons.person_outline_rounded,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your phone or account number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Password field ──────────────────────────
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _pill(
                          'Password',
                          Icons.lock_outline_rounded,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFFB0BEC5),
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitLogin(),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // ── Sign in button ──────────────────────────
                      ElevatedButton(
                        onPressed:
                            authState.isLoading ? null : _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                      const SizedBox(height: 20),

                      // ── Register link ───────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13),
                          ),
                          TextButton(
                            onPressed: authState.isLoading
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen()),
                                    ),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
