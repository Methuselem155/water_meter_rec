import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill.dart';
import '../services/bill_service.dart';
import '../providers/auth_provider.dart';

class BillRepository {
  final BillService _billService;

  BillRepository(this._billService);

  Future<PaginatedBills> getBills({
    int page = 1,
    int limit = 10,
    String? status,
  }) {
    return _billService.fetchBills(page: page, limit: limit, status: status);
  }

  Future<Bill> getBillById(String id) {
    return _billService.fetchBillById(id);
  }

  Future<BillSummary> getBillsSummary() {
    return _billService.fetchBillsSummary();
  }
}

// ----------------------------------------------------
// Providers
// ----------------------------------------------------
final billServiceProvider = Provider<BillService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return BillService(dio);
});

final billRepositoryProvider = Provider<BillRepository>((ref) {
  final service = ref.watch(billServiceProvider);
  return BillRepository(service);
});

/// Fetches bill summary once — used by HomeScreen summary cards.
final billSummaryProvider = FutureProvider<BillSummary>((ref) {
  return ref.read(billRepositoryProvider).getBillsSummary();
});
