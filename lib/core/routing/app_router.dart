import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../storage/token_storage.dart';
import '../../features/public/landing_screen.dart';
import '../../features/public/job_board_screen.dart';
import '../../features/public/job_details_public_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/interview/ai_interview_screen.dart';
import '../../features/candidate/candidate_dashboard_screen.dart';
import '../../features/candidate/candidate_profile_screen.dart';
import '../../features/candidate/candidate_resumes_screen.dart';
import '../../features/candidate/candidate_applications_screen.dart';
import '../../features/candidate/interview_prep_screen.dart';
import '../../features/recruiter/recruiter_dashboard_screen.dart';
import '../../features/recruiter/recruiter_create_job_screen.dart';
import '../../features/recruiter/recruiter_jobs_screen.dart';
import '../../features/recruiter/recruiter_pipeline_screen.dart';
import '../../features/recruiter/recruiter_candidate_search_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/messaging/messaging_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) async {
    final path = state.uri.path;
    final cachedUser = await TokenStorage.getUser();
    final hasToken = await TokenStorage.getAccessToken();

    final isLoggedIn = (hasToken != null && hasToken.isNotEmpty) && (cachedUser != null);

    if (isLoggedIn) {
      final role = (cachedUser['role'] ?? '').toString().toUpperCase();
      String targetDashboard = '/candidate/dashboard';
      if (role == 'RECRUITER') {
        targetDashboard = '/recruiter/dashboard';
      } else if (role == 'SUPER_ADMIN') {
        targetDashboard = '/admin/dashboard';
      }

      // If user is already logged in, redirect away from public landing/auth pages to their dashboard
      if (path == '/' || path == '/login' || path == '/register') {
        return targetDashboard;
      }
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: '/live-interview',
      builder: (context, state) {
        final room = state.uri.queryParameters['room'];
        final id = state.uri.queryParameters['id'];
        return AIInterviewScreen(initialRoomId: room, initialInterviewId: id);
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/jobs',
      builder: (context, state) => const JobBoardScreen(),
    ),
    GoRoute(
      path: '/jobs/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '1') ?? 1;
        return JobDetailsPublicScreen(jobId: id);
      },
    ),
    // 1-on-1 Direct Messaging & AI auto-suggestion chat
    GoRoute(
      path: '/messages',
      builder: (context, state) {
        final uid = int.tryParse(state.uri.queryParameters['user_id'] ?? '');
        return MessagingScreen(initialContactUserId: uid);
      },
    ),
    // Candidate routes
    GoRoute(
      path: '/candidate/dashboard',
      builder: (context, state) => const CandidateDashboardScreen(),
    ),
    GoRoute(
      path: '/candidate/profile',
      builder: (context, state) => const CandidateProfileScreen(),
    ),
    GoRoute(
      path: '/candidate/resumes',
      builder: (context, state) => const CandidateResumesScreen(),
    ),
    GoRoute(
      path: '/candidate/applications',
      builder: (context, state) => const CandidateApplicationsScreen(),
    ),
    GoRoute(
      path: '/candidate/prep',
      builder: (context, state) => const InterviewPrepScreen(),
    ),
    // Recruiter routes
    GoRoute(
      path: '/recruiter/dashboard',
      builder: (context, state) => const RecruiterDashboardScreen(),
    ),
    GoRoute(
      path: '/recruiter/create-job',
      builder: (context, state) => const RecruiterCreateJobScreen(),
    ),
    GoRoute(
      path: '/recruiter/jobs',
      builder: (context, state) => const RecruiterJobsScreen(),
    ),
    GoRoute(
      path: '/recruiter/pipeline',
      builder: (context, state) => const RecruiterPipelineScreen(),
    ),
    GoRoute(
      path: '/recruiter/candidates',
      builder: (context, state) => const RecruiterCandidateSearchScreen(),
    ),
    // Admin routes
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
  ],
);
