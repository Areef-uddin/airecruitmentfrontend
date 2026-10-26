import 'job_model.dart';
import 'user_model.dart';

class ApplicationModel {
  final int id;
  final JobModel? job;
  final UserModel? candidate;
  final String coverLetter;
  final String status;
  final double? aiMatchScore;
  final String? aiMatchExplanation;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String appliedAt;
  final String? interviewLink;
  final int? interviewId;

  ApplicationModel({
    required this.id,
    this.job,
    this.candidate,
    this.coverLetter = '',
    required this.status,
    this.aiMatchScore,
    this.aiMatchExplanation,
    this.matchedSkills = const [],
    this.missingSkills = const [],
    this.appliedAt = '',
    this.interviewLink,
    this.interviewId,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return ApplicationModel(
      id: json['id'] ?? 0,
      job: json['job'] != null ? JobModel.fromJson(json['job']) : null,
      candidate: json['candidate'] != null ? UserModel.fromJson(json['candidate']) : null,
      coverLetter: json['cover_letter'] ?? '',
      status: json['status'] ?? 'SUBMITTED',
      aiMatchScore: toDouble(json['ai_match_score']),
      aiMatchExplanation: json['ai_match_explanation'],
      matchedSkills: json['ai_matched_skills'] != null ? List<String>.from(json['ai_matched_skills']) : [],
      missingSkills: json['ai_missing_skills'] != null ? List<String>.from(json['ai_missing_skills']) : [],
      appliedAt: json['applied_at'] ?? '',
      interviewLink: json['interview_link'],
      interviewId: json['interview_id'],
    );
  }
}
