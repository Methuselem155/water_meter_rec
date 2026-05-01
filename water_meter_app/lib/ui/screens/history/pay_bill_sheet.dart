import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../models/bill.dart';
import '../../../repositories/payment_repository.dart';
import 'payment_waiting_screen.dart';

class PayBillSheet extends ConsumerStatefulWidget {
  final Bill bill;
  final String? savedPhone;

  const PayBillSheet({super.key, required this.bill, this.savedPhone});

  @override
  ConsumerState<PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends ConsumerState<PayBillSheet> {
  late final TextEditingController _phoneCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.savedPhone ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your Mobile Money phone number');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final transactionRef = await ref
          .read(paymentRepositoryProvider)
          .initiateCashin(widget.bill.id, phone);

      if (!mounted) return;
      Navigator.pop(context); // close bottom sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentWaitingScreen(
            transactionRef: transactionRef,
            bill: widget.bill,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.bill.totalAmountVatInclusive ?? widget.bill.totalAmount;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Pay Bill',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your Mobile Money number to pay\nRWF ${amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Mobile Money Number',
              hintText: '078XXXXXXX',
              prefixIcon: Icon(Icons.phone_android_rounded),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
            ),
          ],

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Pay RWF ${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
