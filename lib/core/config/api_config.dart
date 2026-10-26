import 'package:flutter/foundation.dart';

class ApiConfig {
  // Production Live Render Backend URL
  static const String liveProductionUrl = 'https://airecruitmentbackend.onrender.com/api';

  // Manual runtime override if needed
  static String? overrideBaseUrl;

  static String get baseUrl {
    if (overrideBaseUrl != null && overrideBaseUrl!.isNotEmpty) {
      return overrideBaseUrl!;
    }

    // 1. Check compile-time environment flag: --dart-define=API_URL=...
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // 2. Default to Live Render Production URL
    return liveProductionUrl;
  }

  // Endpoints
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String refreshToken = '/auth/token/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';

  // Candidates
  static const String candidateMe = '/candidates/me/';
  static const String candidateSkills = '/candidates/skills/';
  static const String candidateManageSkill = '/candidates/skills/manage/';
  static const String recommendedJobs = '/candidates/recommended-jobs/';

  // Jobs
  static const String jobs = '/jobs/';
  static const String savedJobs = '/jobs/saved/';

  // Applications
  static const String applications = '/applications/';
  static String applyJob(int jobId) => '/applications/apply/$jobId/';
  static String updateApplicationStatus(int id) => '/applications/$id/status/';

  // Resumes
  static const String resumes = '/resumes/';

  // Recruiters
  static const String recruiterDashboard = '/recruiter/dashboard/';
  static const String recruiterCandidates = '/recruiter/candidates/';

  // Interviews
  static const String interviews = '/interviews/';
  static String evaluateInterview(int id) => '/interviews/$id/ai-evaluate/';
  static const String interviewRoomStatus = '/interviews/room-status/';
  static const String interviewRoomJoin = '/interviews/room-join/';
  static const String interviewRoomHeartbeat = '/interviews/room-heartbeat/';
  static const String interviewRoomLeave = '/interviews/room-leave/';
  static const String interviewSignal = '/interviews/signal/';

  // Notifications
  static const String notifications = '/notifications/';
  static const String markAllNotificationsRead = '/notifications/mark-all-read/';

  // Messaging
  static const String conversations = '/messaging/conversations/';

  // AI Services
  static const String aiResumeParse = '/ai/resume-parse/';
  static const String aiGenerateJobDesc = '/ai/generate-job-description/';
  static const String aiMatchCandidate = '/ai/match-candidate/';
  static const String aiGenerateQuestions = '/ai/generate-interview-questions/';
  static const String aiAssistant = '/ai/assistant/';
  static const String aiTranslate = '/ai/translate/';
  static const String aiImproveText = '/ai/improve-text/';

  // Admin
  static const String adminDashboard = '/admin/dashboard/';
  static const String adminUsers = '/admin/users/';
}
