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

class AuthRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final authRouterNotifierProvider = Provider<AuthRouterNotifier>((ref) {
  return AuthRouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authRouterNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final user = authState.user;
      final isAuth = authState.isAuthenticated && user != null;
      final path = state.uri.path;

      final isAuthRoute = path == '/login' || path == '/register';
      final isLandingRoute = path == '/';
      final isCandidateRoute = path.startsWith('/candidate');
      final isRecruiterRoute = path.startsWith('/recruiter');
      final isAdminRoute = path.startsWith('/admin');

      // 1. If user is already authenticated:
      if (isAuth) {
        final targetDashboard = user.isRecruiter
            ? '/recruiter/dashboard'
            : (user.isCandidate ? '/candidate/dashboard' : '/admin/dashboard');

        // Prevent staying on landing or auth pages when logged in -> redirect straight to dashboard
        if (isLandingRoute || isAuthRoute) {
          return targetDashboard;
        }

        // Prevent candidate from accessing recruiter/admin or vice-versa
        if (user.isCandidate && (isRecruiterRoute || isAdminRoute)) {
          return '/candidate/dashboard';
        }
        if (user.isRecruiter && (isCandidateRoute || isAdminRoute)) {
          return '/recruiter/dashboard';
        }
      }

      // 2. If user is NOT authenticated:
      if (!isAuth && !authState.isLoading) {
        if (isCandidateRoute || isRecruiterRoute || isAdminRoute) {
          return '/login';
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
    ],
  );
});

// Fallback singleton
final appRouter = GoRouter(
  initialLocation: '/',
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
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
  ],
);
