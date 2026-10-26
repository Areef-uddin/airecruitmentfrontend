import 'application_model.dart';

class TranscriptEntry {
  final String speaker;
  final String role;
  final String text;

  TranscriptEntry({
    required this.speaker,
    required this.role,
    required this.text,
  });

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) {
    return TranscriptEntry(
      speaker: json['speaker'] ?? 'Interviewer',
      role: json['role'] ?? '',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speaker': speaker,
      'role': role,
      'text': text,
    };
  }
}

class InterviewModel {
  final int id;
  final ApplicationModel? application;
  final String title;
  final String interviewType;
  final String scheduledAt;
  final int durationMinutes;
  final String meetingLink;
  final String status;
  final double? aiScore;
  final String? aiFeedback;
  final List<TranscriptEntry> transcript;

  InterviewModel({
    required this.id,
    this.application,
    required this.title,
    this.interviewType = 'AI_SCREENING',
    required this.scheduledAt,
    this.durationMinutes = 30,
    this.meetingLink = '',
    this.status = 'SCHEDULED',
    this.aiScore,
    this.aiFeedback,
    this.transcript = const [],
  });

  factory InterviewModel.fromJson(Map<String, dynamic> json) {
    List<TranscriptEntry> transcriptList = [];
    if (json['ai_transcript'] != null && json['ai_transcript'] is List) {
      transcriptList = (json['ai_transcript'] as List)
          .map((t) => TranscriptEntry.fromJson(t))
          .toList();
    }

    double? toDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    int toInt(dynamic val, [int def = 0]) {
      if (val == null) return def;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? def;
      return def;
    }

    return InterviewModel(
      id: toInt(json['id']),
      application: json['application'] != null && json['application'] is Map<String, dynamic>
          ? ApplicationModel.fromJson(json['application'])
          : null,
      title: json['title'] ?? 'AI Interview Session',
      interviewType: json['interview_type'] ?? 'AI_SCREENING',
      scheduledAt: json['scheduled_at'] ?? '',
      durationMinutes: toInt(json['duration_minutes'], 30),
      meetingLink: json['meeting_link'] ?? '',
      status: json['status'] ?? 'SCHEDULED',
      aiScore: toDouble(json['ai_score']),
      aiFeedback: json['ai_feedback'],
      transcript: transcriptList,
    );
  }
}
