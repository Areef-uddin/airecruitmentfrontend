import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/interview_model.dart';

class RoomStatusData {
  final String room;
  final List<dynamic> participants;
  final int participantCount;
  final Map<String, dynamic>? interview;

  RoomStatusData({
    required this.room,
    required this.participants,
    required this.participantCount,
    this.interview,
  });

  factory RoomStatusData.fromJson(Map<String, dynamic> json) {
    return RoomStatusData(
      room: json['room'] ?? '',
      participants: json['participants'] ?? [],
      participantCount: json['participant_count'] ?? 0,
      interview: json['interview'],
    );
  }
}

class InterviewRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<InterviewModel>> getInterviews() async {
    try {
      final response = await _dio.get(ApiConfig.interviews);
      final List list = response.data is List ? response.data : (response.data['results'] ?? []);
      return list.map((item) => InterviewModel.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<InterviewModel> getInterview(int id) async {
    final response = await _dio.get('${ApiConfig.interviews}$id/');
    return InterviewModel.fromJson(response.data);
  }

  Future<InterviewModel> scheduleInterview({
    int? applicationId,
    int? candidateId,
    int? jobId,
    String? title,
    String? scheduledAt,
    int durationMinutes = 45,
    String? room,
    String? meetingLink,
  }) async {
    final response = await _dio.post(
      ApiConfig.interviews,
      data: {
        if (applicationId != null) 'application_id': applicationId,
        if (candidateId != null) 'candidate_id': candidateId,
        if (jobId != null) 'job_id': jobId,
        'title': title ?? 'Technical Screening Session',
        'scheduled_at': scheduledAt ?? DateTime.now().toIso8601String(),
        'duration_minutes': durationMinutes,
        if (room != null && room.isNotEmpty) 'room': room,
        if (meetingLink != null && meetingLink.isNotEmpty) 'meeting_link': meetingLink,
      },
    );
    return InterviewModel.fromJson(response.data);
  }

  Future<RoomStatusData> getRoomStatus(String room, {int? id}) async {
    final response = await _dio.get(
      ApiConfig.interviewRoomStatus,
      queryParameters: {
        'room': room,
        if (id != null) 'id': id,
      },
    );
    return RoomStatusData.fromJson(response.data);
  }

  Future<void> sendSignal({
    required String room,
    required String fromUser,
    String? toUser,
    required String type,
    required dynamic payload,
  }) async {
    try {
      await _dio.post(
        ApiConfig.interviewSignal,
        data: {
          'room': room,
          'from_user': fromUser,
          if (toUser != null && toUser.isNotEmpty) 'to_user': toUser,
          'type': type,
          'payload': payload,
        },
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getSignals({
    required String room,
    required String userId,
    required int sinceId,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.interviewSignal,
        queryParameters: {
          'room': room,
          'user_id': userId,
          'since': sinceId,
        },
      );
      final List list = response.data['signals'] ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> joinRoom(String room, {String? userId, String? role, String? name, bool? videoOn, bool? micOn}) async {
    try {
      await _dio.post(
        ApiConfig.interviewRoomJoin,
        data: {
          'room': room,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
          if (role != null) 'role': role,
          if (name != null) 'name': name,
          if (videoOn != null) 'video_on': videoOn,
          if (micOn != null) 'mic_on': micOn,
        },
      );
    } catch (_) {}
  }

  Future<void> sendHeartbeat(String room, {String? userId, bool? videoOn, bool? micOn}) async {
    try {
      await _dio.post(
        ApiConfig.interviewRoomHeartbeat,
        data: {
          'room': room,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
          if (videoOn != null) 'video_on': videoOn,
          if (micOn != null) 'mic_on': micOn,
        },
      );
    } catch (_) {}
  }

  Future<void> leaveRoom(String room, {String? userId}) async {
    try {
      await _dio.post(
        ApiConfig.interviewRoomLeave,
        data: {
          'room': room,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
        },
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> evaluateInterview(int id, List<Map<String, String>> transcript) async {
    final response = await _dio.post(
      ApiConfig.evaluateInterview(id),
      data: {'transcript': transcript},
    );
    return response.data;
  }

  Future<String> translateText(String text, String targetLanguage) async {
    if (text.isEmpty) return '';
    try {
      final response = await _dio.post(
        ApiConfig.aiTranslate,
        data: {
          'text': text,
          'target_language': targetLanguage,
        },
      );
      return response.data['translated'] ?? text;
    } catch (_) {
      return text;
    }
  }

  Future<Map<String, dynamic>> improveText(String text, {String mode = 'grammar'}) async {
    if (text.isEmpty) return {'original': text, 'improved': text, 'suggestions': []};
    try {
      final response = await _dio.post(
        ApiConfig.aiImproveText,
        data: {
          'text': text,
          'mode': mode,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } catch (_) {
      return {
        'original': text,
        'improved': text.capitalize(),
        'suggestions': ['✨ Polish: ${text.capitalize()}']
      };
    }
  }

  Future<String> askAssistant(String message, {String role = 'RECRUITER'}) async {
    if (message.isEmpty) return '';
    try {
      final response = await _dio.post(
        ApiConfig.aiAssistant,
        data: {'message': message},
      );
      return response.data['reply'] ?? 'I am here to assist with this technical interview.';
    } catch (_) {
      return 'AI Copilot: You can ask candidate about system design trade-offs, state management patterns, and production debugging.';
    }
  }

  Future<List<String>> generateQuestions(String jobTitle, List<String> skills) async {
    try {
      final response = await _dio.post(
        ApiConfig.aiGenerateQuestions,
        data: {
          'title': jobTitle,
          'skills': skills,
        },
      );
      final List qs = response.data['questions'] ?? [];
      return qs.map((q) => q.toString()).toList();
    } catch (_) {
      return [
        'Can you describe your experience designing scalable APIs?',
        'How do you manage state and asynchronous operations in frontend applications?',
        'What strategies do you use for performance profiling and error logging?',
        'Explain a complex technical bug you solved recently and your thought process.',
      ];
    }
  }

  Future<void> updateInterviewStatus(int id, String status) async {
    try {
      await _dio.patch(
        '${ApiConfig.interviews}$id/',
        data: {'status': status},
      );
    } catch (_) {}
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
