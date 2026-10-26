import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';

class RecruiterDashboardData {
  final Map<String, dynamic> metrics;
  final List<dynamic> pipeline;
  final List<dynamic> recentApplicants;

  RecruiterDashboardData({
    required this.metrics,
    required this.pipeline,
    required this.recentApplicants,
  });

  factory RecruiterDashboardData.fromJson(Map<String, dynamic> json) {
    return RecruiterDashboardData(
      metrics: json['metrics'] ?? {},
      pipeline: json['pipeline'] ?? [],
      recentApplicants: json['recent_applicants'] ?? [],
    );
  }
}

class RecruiterRepository {
  final Dio _dio = ApiClient().dio;

  Future<RecruiterDashboardData> getDashboardData() async {
    final response = await _dio.get(ApiConfig.recruiterDashboard);
    return RecruiterDashboardData.fromJson(response.data);
  }

  Future<List<dynamic>> searchCandidates({String? query, String? skill, String? location}) async {
    final response = await _dio.get(
      ApiConfig.recruiterCandidates,
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (skill != null && skill.isNotEmpty) 'skill': skill,
        if (location != null && location.isNotEmpty) 'location': location,
      },
    );
    return response.data['results'] ?? [];
  }
}
