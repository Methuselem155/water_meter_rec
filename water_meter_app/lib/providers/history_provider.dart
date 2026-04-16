import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading.dart';
import '../models/bill.dart';
import '../repositories/reading_repository.dart';
import '../repositories/bill_repository.dart';

// Sentinel to distinguish "not passed" from explicit null in copyWith
const _keep = Object();

// Controls the active bottom nav tab index from anywhere in the app
final activeTabProvider = StateProvider<int>((ref) => 0);

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

  // Active status filter for bills: null = All
  final String? billStatusFilter;

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
    this.showingBills = false,
    this.billStatusFilter,
  });

  HistoryState copyWith({
    List<Reading>? readings,
    List<Bill>? bills,
    bool? isLoading,
    bool? isFetchingMore,
    Object? error = _keep, // use sentinel so null can explicitly clear the error
    int? readingPage,
    bool? hasMoreReadings,
    int? billPage,
    bool? hasMoreBills,
    bool? showingBills,
    Object? billStatusFilter = _keep,
  }) {
    return HistoryState(
      readings: readings ?? this.readings,
      bills: bills ?? this.bills,
      isLoading: isLoading ?? this.isLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      error: identical(error, _keep) ? this.error : error as String?,
      readingPage: readingPage ?? this.readingPage,
      hasMoreReadings: hasMoreReadings ?? this.hasMoreReadings,
      billPage: billPage ?? this.billPage,
      hasMoreBills: hasMoreBills ?? this.hasMoreBills,
      showingBills: showingBills ?? this.showingBills,
      billStatusFilter: identical(billStatusFilter, _keep)
          ? this.billStatusFilter
          : billStatusFilter as String?,
    );
  }
}

// ------------------------------------------------------------------
// The unified notifier caching the arrays locally
// ------------------------------------------------------------------
class HistoryNotifier extends Notifier<HistoryState> {
  late ReadingRepository _readingRepo;
  late BillRepository _billRepo;
  bool _isDisposed = false;

  @override
  HistoryState build() {
    _readingRepo = ref.read(readingRepositoryProvider);
    _billRepo = ref.read(billRepositoryProvider);

    ref.onDispose(() => _isDisposed = true);

    // Kick off initial fetch once on first build only
    Future.microtask(() {
      if (!_isDisposed) _performInitialFetch();
    });

    return HistoryState();
  }

  bool get mounted => !_isDisposed;

  /// Perform initial data fetch
  Future<void> _performInitialFetch() async {
    if (_isDisposed) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([
        _fetchReadings(refresh: true),
        _fetchBills(refresh: true),
      ]);
    } catch (e) {
      if (!_isDisposed) state = state.copyWith(error: e.toString());
    } finally {
      if (!_isDisposed) state = state.copyWith(isLoading: false);
    }
  }

  void toggleView() {
    state = state.copyWith(showingBills: !state.showingBills);
    // If we toggle to bills and haven't loaded any bills yet, load them
    if (state.showingBills && state.bills.isEmpty && state.hasMoreBills) {
      _fetchBills(refresh: true);
    }
  }

  /// Change the active bill status filter and reload bills.
  void setStatusFilter(String? status) {
    state = state.copyWith(
      billStatusFilter: status,
      bills: [],
      billPage: 1,
      hasMoreBills: true,
    );
    _fetchBills(refresh: true);
  }

  /// Prepend a freshly uploaded reading to the top of the list immediately,
  /// then refresh from server in the background to stay in sync.
  void prependReading(Reading reading) {
    final alreadyExists = state.readings.any((r) => r.id == reading.id);
    if (!alreadyExists) {
      state = state.copyWith(readings: [reading, ...state.readings]);
    }
    // Background refresh — replaces the optimistic entry with server truth
    Future.microtask(() async {
      if (!_isDisposed) await _fetchReadings(refresh: true);
    });
  }

  /// Public method to manually refresh readings and bills
  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([
        _fetchReadings(refresh: true),
        _fetchBills(refresh: true),
      ]);
    } finally {
      state = state.copyWith(isLoading: false);
    }
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
      final paginatedResult = await _billRepo.getBills(
        page: page,
        status: state.billStatusFilter,
      );

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
