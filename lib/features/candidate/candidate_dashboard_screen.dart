import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/sidebar_navigation.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/score_gauge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../models/interview_model.dart';
import '../../repositories/interview_repository.dart';

class CandidateDashboardScreen extends ConsumerStatefulWidget {
  const CandidateDashboardScreen({super.key});

  @override
  ConsumerState<CandidateDashboardScreen> createState() => _CandidateDashboardScreenState();
}

class _CandidateDashboardScreenState extends ConsumerState<CandidateDashboardScreen> {
  final InterviewRepository _interviewRepo = InterviewRepository();
  List<InterviewModel> _interviews = [];
  bool _isLoadingInterviews = true;

  @override
  void initState() {
    super.initState();
    _loadInterviews();
  }

  void _loadInterviews() async {
    try {
      final res = await _interviewRepo.getInterviews();
      if (mounted) {
        setState(() {
          _interviews = res;
          _isLoadingInterviews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInterviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final recommendedAsync = ref.watch(recommendedJobsProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final candidateName = user?.fullName ?? user?.email.split('@').first ?? 'Candidate';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopNavbar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  SidebarNavigation(user: user, currentRoute: '/candidate/dashboard'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Banner
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E1F30), Color(0xFF141522)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back, $candidateName 👋',
                                      style: AppTypography.displaySmall.copyWith(fontSize: 26),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Your AI verified profile is active. Browse live job postings or join your scheduled recruiter interviews below.',
                                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 10,
                                      children: [
                                        AppButton(
                                          label: 'Upload / Update Resume',
                                          variant: AppButtonVariant.primary,
                                          icon: const Icon(Icons.upload_file, size: 18, color: Colors.white),
                                          onPressed: () => context.go('/candidate/resumes'),
                                        ),
                                        AppButton(
                                          label: 'Browse All Jobs',
                                          variant: AppButtonVariant.secondary,
                                          icon: const Icon(Icons.search, size: 18, color: AppColors.textPrimary),
                                          onPressed: () => context.go('/jobs'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isDesktop) ...[
                                const SizedBox(width: 24),
                                const Column(
                                  children: [
                                    ScoreGauge(score: 94, size: 90, strokeWidth: 10),
                                    SizedBox(height: 8),
                                    Text('Profile Match Rating', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // UPCOMING INTERVIEWS / INVITATIONS SECTION
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.videocam, color: Color(0xFFD946EF), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Live Interview Invitations',
                                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: _loadInterviews,
                              icon: const Icon(Icons.refresh, color: AppColors.primary, size: 20),
                              tooltip: 'Refresh Invitations',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (_isLoadingInterviews)
                          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary)))
                        else if (_interviews.isEmpty)
                          AppCard(
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD946EF).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.25)),
                                    ),
                                    child: const Icon(Icons.event_available, color: Color(0xFFD946EF), size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('No Scheduled Interviews', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                        SizedBox(height: 4),
                                        Text('You do not have any pending live interviews scheduled right now. When a recruiter invites you for an interview, it will appear here with an instant "Join Room" button.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _interviews.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final it = _interviews[idx];
                              final roomTarget = it.meetingLink.isNotEmpty
                                  ? (it.meetingLink.contains('id=') ? it.meetingLink : '${it.meetingLink}&id=${it.id}')
                                  : '/live-interview?room=interview_${it.id}&id=${it.id}';

                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161826),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.35)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD946EF).withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.video_call, color: Color(0xFFD946EF), size: 26),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(it.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Status: ${it.status} • Duration: ${it.durationMinutes} mins',
                                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                              ),
                                              if (it.aiScore != null) ...[
                                                const SizedBox(height: 6),
                                                Text('AI Evaluation Score: ${it.aiScore!.toInt()}/100', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (isDesktop) ...[
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              final origin = kIsWeb ? Uri.base.origin : 'http://localhost:3000';
                                              final fullUrl = '$origin/#$roomTarget';
                                              Clipboard.setData(ClipboardData(text: fullUrl));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: const Color(0xFF10B981),
                                                  content: Text('Interview Link copied: $fullUrl'),
                                                ),
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              side: const BorderSide(color: Color(0xFF2E324D)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            ),
                                            icon: const Icon(Icons.copy, size: 16),
                                            label: const Text('Share Link', style: TextStyle(fontSize: 12)),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton.icon(
                                            onPressed: () => context.go(roomTarget),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD946EF),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            icon: const Icon(Icons.login, size: 18),
                                            label: const Text('Join Interview Room', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (!isDesktop) ...[
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                final origin = kIsWeb ? Uri.base.origin : 'http://localhost:3000';
                                                final fullUrl = '$origin/#$roomTarget';
                                                Clipboard.setData(ClipboardData(text: fullUrl));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    backgroundColor: const Color(0xFF10B981),
                                                    content: Text('Interview Link copied: $fullUrl'),
                                                  ),
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(color: Color(0xFF2E324D)),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                              icon: const Icon(Icons.copy, size: 14),
                                              label: const Text('Share Link', style: TextStyle(fontSize: 12)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => context.go(roomTarget),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFD946EF),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.login, size: 16),
                                              label: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 36),

                        // RECOMMENDED JOBS WITH AI FIT
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Active Job Opportunities',
                              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: () => context.go('/jobs'),
                              icon: const Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                              label: const Text('View All Jobs', style: TextStyle(color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        recommendedAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          ),
                          error: (e, _) => AppCard(
                            child: Text('Unable to load jobs: $e'),
                          ),
                          data: (jobs) {
                            if (jobs.isEmpty) {
                              return const AppCard(child: Text('No active jobs found right now.'));
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: jobs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final job = jobs[index];
                                return AppCard(
                                  onTap: () => context.go('/jobs/${job.id}'),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.business, color: AppColors.primary, size: 26),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    job.title,
                                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                if (job.matchPercentage != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withOpacity(0.18),
                                                      borderRadius: BorderRadius.circular(100),
                                                      border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '${job.matchPercentage!.toInt()}% Match',
                                                          style: AppTypography.labelSmall.copyWith(
                                                            color: AppColors.primary,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${job.company?.name ?? "Engineering Team"} • ${job.location} • ${job.jobType}',
                                              style: AppTypography.bodySmall,
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: job.skills.take(5).map((s) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceLight,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(s, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
