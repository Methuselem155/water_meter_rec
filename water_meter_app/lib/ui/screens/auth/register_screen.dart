import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _meterSerialController = TextEditingController();
  
  String? _selectedCategory = 'RESIDENTIAL';
  final List<String> _categories = ['PUBLIC TAP', 'RESIDENTIAL', 'NON RESIDENTIAL', 'INDUSTRIES'];

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

    if (_formKey.currentState!.validate()) {
      final request = RegisterRequest(
        accountNumber: _accountNumberController.text.trim(),
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        // Only submit if effectively typed
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        password: _passwordController.text,
        meterSerialNumber: _meterSerialController.text.trim(),
        category: _selectedCategory ?? 'RESIDENTIAL',
      );

      final success = await ref.read(authProvider.notifier).register(request);

      if (!mounted) return;

      if (success) {
        // Destroy routing history so back button closes app instead of returning to login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Registration failed.'),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join the Water Meter System',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text('Provide your meter details to get started.'),
                const SizedBox(height: 24),

                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person)),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value!.trim().isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: _phoneNumberController,
                  decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value!.trim().isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 16),

                // Account Number
                TextFormField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(labelText: 'Account Number *', prefixIcon: Icon(Icons.numbers)),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value!.trim().isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 16),

                // Meter Serial Number
                TextFormField(
                  controller: _meterSerialController,
                  decoration: const InputDecoration(
                    labelText: 'Meter Serial / ID *', 
                    prefixIcon: Icon(Icons.speed),
                    helperText: 'Found etched directly on the physical meter glass.',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value!.trim().isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 16),

                // Customer Category
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Customer Category *',
                    prefixIcon: Icon(Icons.category),
                    helperText: 'Select your customer type for tariff calculation.',
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a category' : null,
                ),
                const SizedBox(height: 16),

                // Email (Optional)
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address (Optional)', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock)),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitRegistration(),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required field';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Account', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
