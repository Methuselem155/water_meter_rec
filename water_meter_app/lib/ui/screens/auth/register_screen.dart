import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../models/auth_request.dart';
import '../../../providers/auth_provider.dart';
import '../../../main.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _accountNumberController = TextEditingController();
  final _fullNameController      = TextEditingController();
  final _phoneNumberController   = TextEditingController();
  final _emailController         = TextEditingController();
  final _passwordController      = TextEditingController();
  final _meterSerialController   = TextEditingController();

  String? _selectedCategory = 'RESIDENTIAL';
  bool _obscurePassword = true;
  bool _agreedToTerms   = false;

  static const _categories = [
    'PUBLIC TAP',
    'RESIDENTIAL',
    'NON RESIDENTIAL',
    'INDUSTRIES',
  ];

  @override
  void dispose() {
    _accountNumberController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _meterSerialController.dispose();
    super.dispose();
  }

  void _submitRegistration() async {
    FocusScope.of(context).unfocus();
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        _errorSnack('Please agree to the Terms & Conditions to continue.'),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      final request = RegisterRequest(
        accountNumber:    _accountNumberController.text.trim(),
        fullName:         _fullNameController.text.trim(),
        phoneNumber:      _phoneNumberController.text.trim(),
        email:            _emailController.text.trim().isEmpty
                            ? null
                            : _emailController.text.trim(),
        password:         _passwordController.text,
        meterSerialNumber: _meterSerialController.text.trim(),
        category:         _selectedCategory ?? 'RESIDENTIAL',
      );

      final success = await ref.read(authProvider.notifier).register(request);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context)
            .showSnackBar(_errorSnack(error ?? 'Registration failed.'));
        ref.read(authProvider.notifier).clearError();
      }
    }
  }

  SnackBar _errorSnack(String msg) => SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

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
    String? helper,
  }) =>
      InputDecoration(
        hintText: hint,
        helperText: helper,
        hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
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
    final authState  = ref.watch(authProvider);
    final screenH    = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF81D4FA), AppTheme.primaryBlue],
              ),
            ),
          ),

          // ── Water drop + branding (top area) ────────────────────────
          Positioned(
            top: screenH * 0.07,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop_rounded,
                      size: 32, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  'WASAC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // ── White card ───────────────────────────────────────────────
          Positioned(
            top: screenH * 0.22,
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
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Title ──────────────────────────────────────
                      const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provide your meter details to get started',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Personal info ──────────────────────────────
                      _label('Personal Information'),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _fullNameController,
                        decoration: _pill('Full Name', Icons.person_outline_rounded),
                        textInputAction: TextInputAction.next,
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _phoneNumberController,
                        decoration: _pill('Phone Number', Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailController,
                        decoration: _pill(
                          'Email Address (Optional)',
                          Icons.email_outlined,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 24),

                      // ── Account & meter ────────────────────────────
                      _label('Account & Meter Details'),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _accountNumberController,
                        decoration: _pill('Account Number', Icons.numbers_rounded),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _meterSerialController,
                        decoration: _pill(
                          'Meter Serial / ID',
                          Icons.speed_rounded,
                          helper: 'Found etched on the physical meter glass.',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: _pill('Customer Category', Icons.category_outlined),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        validator: (v) =>
                            v == null ? 'Please select a category' : null,
                      ),
                      const SizedBox(height: 24),

                      // ── Security ───────────────────────────────────
                      _label('Security'),
                      const SizedBox(height: 10),

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
                        onFieldSubmitted: (_) => _submitRegistration(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 6) return 'At least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Terms checkbox ─────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (v) =>
                                  setState(() => _agreedToTerms = v ?? false),
                              activeColor: AppTheme.primaryBlue,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              side: BorderSide(
                                  color: Colors.grey.shade400, width: 1.5),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                                children: const [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                        color: AppTheme.primaryBlue,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                        color: AppTheme.primaryBlue,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ── Sign up button ─────────────────────────────
                      ElevatedButton(
                        onPressed:
                            authState.isLoading ? null : _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Sign up',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Back button floating over gradient ───────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlue,
          letterSpacing: 0.8,
        ),
      );
}
