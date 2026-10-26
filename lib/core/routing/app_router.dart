import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
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
import '../../features/recruiter/recruiter_dashboard_screen.dart';
import '../../features/recruiter/recruiter_create_job_screen.dart';
import '../../features/recruiter/recruiter_jobs_screen.dart';
import '../../features/recruiter/recruiter_pipeline_screen.dart';
import '../../features/recruiter/recruiter_candidate_search_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) return null;

      final user = authState.user;
      final path = state.uri.path;

      // If user is logged in
      if (user != null) {
        if (path == '/' || path == '/login' || path == '/register') {
          if (user.isCandidate) return '/candidate/dashboard';
          if (user.isRecruiter) return '/recruiter/dashboard';
          return '/admin/dashboard';
        }
      } else {
        // Protected routes require login
        if (path.startsWith('/candidate') ||
            path.startsWith('/recruiter') ||
            path.startsWith('/admin')) {
          return '/login';
        }
      }
      return null;
    },
    routes: _routes,
  );
});

final _routes = [
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
];

// Fallback instance
final appRouter = GoRouter(
  initialLocation: '/',
  routes: _routes,
);
