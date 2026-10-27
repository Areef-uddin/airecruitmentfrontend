import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/application_model.dart';

class ApplicationRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<ApplicationModel>> getApplications({int? jobId, String? status}) async {
    final response = await _dio.get(
      ApiConfig.applications,
      queryParameters: {
        if (jobId != null) 'job_id': jobId,
        if (status != null) 'status': status,
      },
    );

    final List data = response.data['results'] ?? response.data;
    return data.map((a) => ApplicationModel.fromJson(a)).toList();
  }

  Future<ApplicationModel> getApplicationDetail(int id) async {
    final response = await _dio.get('${ApiConfig.applications}$id/');
    return ApplicationModel.fromJson(response.data);
  }

  Future<ApplicationModel> applyToJob(
    int jobId, {
    String coverLetter = '',
    int? resumeId,
    List<int>? resumeBytes,
    String? resumeFileName,
  }) async {
    dynamic payload;
    if (resumeBytes != null && resumeFileName != null) {
      final formData = FormData();
      formData.files.add(MapEntry(
        'resume',
        MultipartFile.fromBytes(resumeBytes, filename: resumeFileName),
      ));
      formData.fields.add(MapEntry('cover_letter', coverLetter));
      payload = formData;
    } else {
      payload = {
        'cover_letter': coverLetter,
        if (resumeId != null) 'resume_id': resumeId,
      };
    }

    final response = await _dio.post(
      ApiConfig.applyJob(jobId),
      data: payload,
    );
    return ApplicationModel.fromJson(response.data);
  }

  Future<void> updateApplicationStatus(int id, String newStatus, {String? notes}) async {
    await _dio.patch(
      ApiConfig.updateApplicationStatus(id),
      data: {
        'status': newStatus,
        if (notes != null) 'recruiter_notes': notes,
      },
    );
  }
}
