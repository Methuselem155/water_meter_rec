import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../models/bill.dart';
import '../../../repositories/payment_repository.dart';

enum _ScreenState { waiting, success, failed, timeout }

class PaymentWaitingScreen extends ConsumerStatefulWidget {
  final String transactionRef;
  final Bill bill;

  const PaymentWaitingScreen({
    super.key,
    required this.transactionRef,
    required this.bill,
  });

  @override
  ConsumerState<PaymentWaitingScreen> createState() =>
      _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends ConsumerState<PaymentWaitingScreen> {
  static const int _maxAttempts = 12;
  static const Duration _interval = Duration(seconds: 5);

  Timer? _timer;
  int _attempts = 0;
  _ScreenState _state = _ScreenState.waiting;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_attempts >= _maxAttempts) {
      _timer?.cancel();
      if (mounted) setState(() => _state = _ScreenState.timeout);
      return;
    }
    _attempts++;

    try {
      final data = await ref
          .read(paymentRepositoryProvider)
          .getTransactionStatus(widget.transactionRef);

      final status = (data['status'] as String? ?? '').toLowerCase();

      if (!mounted) return;

      if (status == 'successful') {
        _timer?.cancel();
        setState(() => _state = _ScreenState.success);
      } else if (status == 'failed') {
        _timer?.cancel();
        setState(() {
          _state = _ScreenState.failed;
          _errorMessage =
              data['message'] as String? ?? 'Payment was declined';
        });
      }
      // pending / processing: keep polling
    } catch (_) {
      // Network error: keep polling until max attempts
    }
  }

  void _retry() {
    setState(() {
      _state = _ScreenState.waiting;
      _attempts = 0;
      _errorMessage = null;
    });
    _startPolling();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state != _ScreenState.waiting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          automaticallyImplyLeading: _state != _ScreenState.waiting,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _ScreenState.waiting:
        return _WaitingView(bill: widget.bill);
      case _ScreenState.success:
        return _SuccessView(
          bill: widget.bill,
          onDone: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
        );
      case _ScreenState.failed:
        return _FailureView(
          message: _errorMessage ?? 'Payment failed. Please try again.',
          onRetry: _retry,
          onCancel: () => Navigator.pop(context),
        );
      case _ScreenState.timeout:
        return _FailureView(
          message:
              'Payment approval timed out. Please check your Mobile Money messages and try again.',
          onRetry: _retry,
          onCancel: () => Navigator.pop(context),
        );
    }
  }
}

// ── Waiting ───────────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  final Bill bill;

  const _WaitingView({required this.bill});

  @override
  Widget build(BuildContext context) {
    final amount = bill.totalAmountVatInclusive ?? bill.totalAmount;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
            child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 32),
        Text(
          'Waiting for approval',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'A Mobile Money prompt has been sent to your phone.\n'
          'Please approve the payment of RWF ${amount.toStringAsFixed(0)}.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Success ───────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final Bill bill;
  final VoidCallback onDone;

  const _SuccessView({required this.bill, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final amount = bill.totalAmountVatInclusive ?? bill.totalAmount;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: const BoxDecoration(
              color: AppTheme.statusPaidBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 44, color: AppTheme.statusPaid),
          ),
        ),
        Text(
          'Payment Successful',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700, color: AppTheme.statusPaid),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'RWF ${amount.toStringAsFixed(0)} has been received.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.statusPaid,
            foregroundColor: Colors.white,
          ),
          child: const Text('Done',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Failure / timeout ─────────────────────────────────────────────────────────

class _FailureView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _FailureView({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded,
                size: 44, color: AppTheme.errorRed),
          ),
        ),
        Text(
          'Payment Failed',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700, color: AppTheme.errorRed),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('Try Again',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
