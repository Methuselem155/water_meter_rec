import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill.dart';
import '../services/bill_service.dart';
import '../providers/auth_provider.dart';

class BillRepository {
  final BillService _billService;

  BillRepository(this._billService);

  Future<PaginatedBills> getBills({int page = 1, int limit = 10}) {
    return _billService.fetchBills(page: page, limit: limit);
  }

  Future<Bill> getBillById(String id) {
    return _billService.fetchBillById(id);
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
