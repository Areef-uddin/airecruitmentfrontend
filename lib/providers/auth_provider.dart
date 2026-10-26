import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserModel? user, bool? isLoading, String? error, bool clearError = false}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => checkCurrentUser());
    return AuthState(isLoading: true);
  }

  Future<void> checkCurrentUser() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      final user = await repo.getCurrentUser();
      state = AuthState(user: user, isLoading: false);
    } catch (_) {
      state = AuthState(user: null, isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.login(email: email, password: password);
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      String errorMessage = 'Invalid credentials. Please verify your email and password.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          if (data['detail'] != null) {
            final detail = data['detail'];
            errorMessage = detail is List ? detail.join(' ') : detail.toString();
          } else if (data['non_field_errors'] != null) {
            final nfe = data['non_field_errors'];
            errorMessage = nfe is List ? nfe.join(' ') : nfe.toString();
          } else if (data['error'] != null) {
            errorMessage = data['error'].toString();
          }
        }
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? companyName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.register(
        email: email,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        companyName: companyName,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      String errorMessage = 'Registration failed. The email may already be in use.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          if (data['detail'] != null) {
            final detail = data['detail'];
            errorMessage = detail is List ? detail.join(' ') : detail.toString();
          } else {
            final firstKey = data.keys.firstOrNull;
            if (firstKey != null) {
              final val = data[firstKey];
              errorMessage = val is List ? "$firstKey: ${val.join(' ')}" : "$firstKey: $val";
            }
          }
        }
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    }
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = AuthState(user: null, isLoading: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
