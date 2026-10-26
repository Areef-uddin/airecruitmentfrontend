import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  final Dio _dio = ApiClient().dio;

  Future<UserModel> login({required String email, required String password}) async {
    final response = await _dio.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
    );

    final tokens = response.data['tokens'];
    await TokenStorage.saveTokens(
      access: tokens['access'],
      refresh: tokens['refresh'],
    );

    final userJson = response.data['user'];
    await TokenStorage.saveUser(userJson);

    return UserModel.fromJson(userJson);
  }

  Future<UserModel> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? companyName,
  }) async {
    final response = await _dio.post(
      ApiConfig.register,
      data: {
        'email': email,
        'username': username,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        if (companyName != null && companyName.isNotEmpty) 'company_name': companyName,
      },
    );

    final tokens = response.data['tokens'];
    await TokenStorage.saveTokens(
      access: tokens['access'],
      refresh: tokens['refresh'],
    );

    final userJson = response.data['user'];
    await TokenStorage.saveUser(userJson);

    return UserModel.fromJson(userJson);
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConfig.me);
      await TokenStorage.saveUser(response.data);
      return UserModel.fromJson(response.data);
    } catch (_) {
      final cached = await TokenStorage.getUser();
      if (cached != null) {
        return UserModel.fromJson(cached);
      }
      return null;
    }
  }

  Future<void> logout() async {
    try {
      final refresh = await TokenStorage.getRefreshToken();
      if (refresh != null) {
        await _dio.post(ApiConfig.logout, data: {'refresh': refresh});
      }
    } catch (_) {}
    await TokenStorage.clear();
  }
}
