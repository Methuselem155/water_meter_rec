import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading.dart';
import '../models/bill.dart';
import '../repositories/reading_repository.dart';
import '../repositories/bill_repository.dart';

// ------------------------------------------------------------------
// State class for Paginated Reading Data
// ------------------------------------------------------------------
class HistoryState {
  final List<Reading> readings;
  final List<Bill> bills;
  final bool isLoading;
  final bool isFetchingMore;
  final String? error;

  // Pagination offsets
  final int readingPage;
  final bool hasMoreReadings;
  final int billPage;
  final bool hasMoreBills;

  // Track which view the user is looking at
  final bool showingBills;

  HistoryState({
    this.readings = const [],
    this.bills = const [],
    this.isLoading = false,
    this.isFetchingMore = false,
    this.error,
    this.readingPage = 1,
    this.hasMoreReadings = true,
    this.billPage = 1,
    this.hasMoreBills = true,
    this.showingBills = false, // Default to showing readings
  });

  HistoryState copyWith({
    List<Reading>? readings,
    List<Bill>? bills,
    bool? isLoading,
    bool? isFetchingMore,
    String? error,
    int? readingPage,
    bool? hasMoreReadings,
    int? billPage,
    bool? hasMoreBills,
    bool? showingBills,
  }) {
    return HistoryState(
      readings: readings ?? this.readings,
      bills: bills ?? this.bills,
      isLoading: isLoading ?? this.isLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      error: error, // Can accept null to clear
      readingPage: readingPage ?? this.readingPage,
      hasMoreReadings: hasMoreReadings ?? this.hasMoreReadings,
      billPage: billPage ?? this.billPage,
      hasMoreBills: hasMoreBills ?? this.hasMoreBills,
      showingBills: showingBills ?? this.showingBills,
    );
  }
}

// ------------------------------------------------------------------
// The unified notifier caching the arrays locally
// ------------------------------------------------------------------
class HistoryNotifier extends Notifier<HistoryState> {
  late ReadingRepository _readingRepo;
  late BillRepository _billRepo;

  @override
  HistoryState build() {
    _readingRepo = ref.watch(readingRepositoryProvider);
    _billRepo = ref.watch(billRepositoryProvider);

    // Initial fetch of both datasets upon provider creation
    refreshAll();

    return HistoryState();
  }

  void toggleView() {
    state = state.copyWith(showingBills: !state.showingBills);
    // If we toggle and haven't loaded data yet, load it
    if (state.showingBills && state.bills.isEmpty && state.hasMoreBills) {
      _fetchBills();
    }
  }

  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.wait([
      _fetchReadings(refresh: true),
      _fetchBills(refresh: true),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isFetchingMore) return;

    if (state.showingBills && state.hasMoreBills) {
      state = state.copyWith(isFetchingMore: true);
      await _fetchBills(refresh: false);
    } else if (!state.showingBills && state.hasMoreReadings) {
      state = state.copyWith(isFetchingMore: true);
      await _fetchReadings(refresh: false);
    }

    state = state.copyWith(isFetchingMore: false);
  }

  Future<void> _fetchReadings({bool refresh = false}) async {
    try {
      final page = refresh ? 1 : state.readingPage + 1;
      final paginatedResult = await _readingRepo.getReadings(page: page);

      state = state.copyWith(
        readings: refresh
            ? paginatedResult.readings
            : [...state.readings, ...paginatedResult.readings],
        readingPage: page,
        hasMoreReadings: paginatedResult.hasNextPage,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _fetchBills({bool refresh = false}) async {
    try {
      final page = refresh ? 1 : state.billPage + 1;
      final paginatedResult = await _billRepo.getBills(page: page);

      state = state.copyWith(
        bills: refresh
            ? paginatedResult.bills
            : [...state.bills, ...paginatedResult.bills],
        billPage: page,
        hasMoreBills: paginatedResult.hasNextPage,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// ----------------------------------------------------
// Global Export Provider
// ----------------------------------------------------
final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(() {
  return HistoryNotifier();
});
