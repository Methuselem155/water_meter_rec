import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/payment_service.dart';
import '../providers/auth_provider.dart';

class PaymentRepository {
  final PaymentService _paymentService;

  PaymentRepository(this._paymentService);

  Future<String> initiateCashin(String billId, String phoneNumber) =>
      _paymentService.initiateCashin(billId, phoneNumber);

  Future<Map<String, dynamic>> getTransactionStatus(String ref) =>
      _paymentService.getTransactionStatus(ref);
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PaymentService(dioClient);
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final service = ref.watch(paymentServiceProvider);
  return PaymentRepository(service);
});
