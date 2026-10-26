import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/job_model.dart';

class JobRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<JobModel>> getJobs({
    String? query,
    String? workplace,
    String? type,
    bool mineOnly = false,
  }) async {
    final response = await _dio.get(
      ApiConfig.jobs,
      queryParameters: {
        if (query != null && query.isNotEmpty) 'search': query,
        if (workplace != null && workplace.isNotEmpty) 'workplace': workplace,
        if (type != null && type.isNotEmpty) 'type': type,
        if (mineOnly) 'mine': 'true',
      },
    );

    final List data = response.data['results'] ?? response.data;
    return data.map((j) => JobModel.fromJson(j)).toList();
  }

  Future<JobModel> getJobDetail(int id) async {
    final response = await _dio.get('${ApiConfig.jobs}$id/');
    return JobModel.fromJson(response.data);
  }

  Future<List<JobModel>> getRecommendedJobs() async {
    final response = await _dio.get(ApiConfig.recommendedJobs);
    final List data = response.data['results'] ?? [];
    return data.map((j) => JobModel.fromJson(j)).toList();
  }

  Future<List<JobModel>> getSavedJobs() async {
    final response = await _dio.get(ApiConfig.savedJobs);
    final List data = response.data['results'] ?? response.data;
    return data.map((j) => JobModel.fromJson(j)).toList();
  }

  Future<bool> toggleSaveJob(int id) async {
    final response = await _dio.post('${ApiConfig.jobs}$id/save/');
    return response.data['saved'] ?? false;
  }

  Future<JobModel> createJob(Map<String, dynamic> jobData) async {
    final response = await _dio.post(ApiConfig.jobs, data: jobData);
    return JobModel.fromJson(response.data);
  }
}
