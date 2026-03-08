import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/auth_request.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';

// ----------------------------------------------------------------------
// Dependency Injection Providers
// ----------------------------------------------------------------------

final dioClientProvider = Provider<DioClient>((ref) => DioClient());

final authServiceProvider = Provider<AuthService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthService(dioClient);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthRepository(authService);
});

// ----------------------------------------------------------------------
// State Management
// ----------------------------------------------------------------------

// Core application auth state containing current user and loading booleans
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading:
          isLoading ?? false, // Intentionally reset loading if overriding
      error: error, // Can cleanly wipe error by passing null explicitly
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// State Notifier to drive Auth Logic across the UI
class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    return const AuthState();
  }

  Future<bool> login(String identifier, String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null); // Clear old errors

      final request = LoginRequest(phoneNumber: identifier, password: password);

      final user = await _repository.login(request);
      state = state.copyWith(user: user, isAuthenticated: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> register(RegisterRequest request) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final user = await _repository.register(request);
      state = state.copyWith(user: user, isAuthenticated: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    state = const AuthState(); // Reset entirely to initial defaults
  }

  // Intended for Splash Screen to silently boot past Login loops
  Future<bool> checkInitialAuth() async {
    state = state.copyWith(isLoading: true, error: null);

    final hasToken = await _repository.hasToken();
    if (hasToken) {
      try {
        // Hydrate the `User` object from the backend
        final user = await _repository.getMe();
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      } catch (e) {
        // If token invalid or network error, logout silently to be safe
        await logout();
        return false;
      }
    }

    state = state.copyWith(isAuthenticated: false, isLoading: false);
    return false;
  }

  // Exposes a way for screens to wipe the snackbar error once displayed
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
