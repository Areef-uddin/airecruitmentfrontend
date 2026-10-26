import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';

class AIRepository {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> generateJobDescription({
    required String title,
    required String experienceLevel,
    required String workplaceType,
    required List<String> skills,
  }) async {
    final response = await _dio.post(
      ApiConfig.aiGenerateJobDesc,
      data: {
        'title': title,
        'experience_level': experienceLevel,
        'workplace_type': workplaceType,
        'skills': skills,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> matchCandidate({required int jobId, int? candidateId}) async {
    final response = await _dio.post(
      ApiConfig.aiMatchCandidate,
      data: {
        'job_id': jobId,
        if (candidateId != null) 'candidate_id': candidateId,
      },
    );
    return response.data;
  }

  Future<List<dynamic>> generateInterviewQuestions({required String jobTitle, List<String>? skills}) async {
    final response = await _dio.post(
      ApiConfig.aiGenerateQuestions,
      data: {
        'title': jobTitle,
        if (skills != null) 'skills': skills,
      },
    );
    return response.data['questions'] ?? [];
  }

  Future<Map<String, dynamic>> evaluateInterview({required int interviewId, required List<Map<String, dynamic>> transcript}) async {
    final response = await _dio.post(
      ApiConfig.evaluateInterview(interviewId),
      data: {'transcript': transcript},
    );
    return response.data;
  }

  Future<String> assistantChat(String message) async {
    final response = await _dio.post(
      ApiConfig.aiAssistant,
      data: {'message': message},
    );
    return response.data['reply'] ?? '';
  }
}
