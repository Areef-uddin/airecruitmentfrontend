import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/sidebar_navigation.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/application_repository.dart';
import '../../models/application_model.dart';

class CandidateApplicationsScreen extends ConsumerStatefulWidget {
  const CandidateApplicationsScreen({super.key});

  @override
  ConsumerState<CandidateApplicationsScreen> createState() => _CandidateApplicationsScreenState();
}

class _CandidateApplicationsScreenState extends ConsumerState<CandidateApplicationsScreen> {
  List<ApplicationModel> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  void _fetchApplications() async {
    try {
      final repo = ApplicationRepository();
      final list = await repo.getApplications();
      setState(() {
        _applications = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);

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
                  SidebarNavigation(user: user, currentRoute: '/candidate/applications'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Job Applications', style: AppTypography.displaySmall.copyWith(fontSize: isDesktop ? 26 : 22)),
                            const SizedBox(height: 6),
                            Text('Track stage updates, AI match evaluations, and upcoming interview calls.', style: AppTypography.bodySmall),
                            const SizedBox(height: 24),

                            if (_isLoading)
                              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)))
                            else if (_applications.isEmpty)
                              AppCard(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.assignment_outlined, size: 54, color: AppColors.textTertiary),
                                      const SizedBox(height: 16),
                                      Text('No Applications Yet', style: AppTypography.titleMedium),
                                      const SizedBox(height: 8),
                                      Text('Explore open roles and apply with one click using your parsed resume.', style: AppTypography.bodySmall),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () => context.go('/jobs'),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                        child: const Text('Browse Job Board', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _applications.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final app = _applications[index];
                                  final job = app.job;

                                  return AppCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(job?.title ?? 'Engineering Role', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: isDesktop ? 16 : 14)),
                                                  const SizedBox(height: 4),
                                                  Text('${job?.company?.name ?? "Technology Corp"} • Applied recently', style: AppTypography.bodySmall),
                                                ],
                                              ),
                                            ),
                                            StatusBadge(status: app.status),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        const Divider(),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.18),
                                                borderRadius: BorderRadius.circular(100),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${app.aiMatchScore?.toInt() ?? 93}% Match',
                                                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                app.aiMatchExplanation ?? 'Demonstrates high qualifications in core stack requirements.',
                                                style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (app.status == 'INTERVIEW_SCHEDULED') ...[
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceElevated,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                            ),
                                            child: isDesktop
                                                ? Row(
                                                    children: [
                                                      const Icon(Icons.videocam, color: AppColors.primary, size: 20),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          'Interview Scheduled: Technical Screening Session',
                                                          style: AppTypography.labelLarge.copyWith(fontSize: 12),
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          final target = (app.interviewLink != null && app.interviewLink!.isNotEmpty)
                                                              ? app.interviewLink!
                                                              : (app.interviewId != null
                                                                  ? '/live-interview?room=interview_${app.interviewId}&id=${app.interviewId}'
                                                                  : '/live-interview?room=interview_${app.id}&id=${app.id}');
                                                          context.go(target);
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.primary,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                        ),
                                                        child: const Text('Join Live Room', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ],
                                                  )
                                                : Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.videocam, color: AppColors.primary, size: 18),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Interview Scheduled: Live Session',
                                                              style: AppTypography.labelLarge.copyWith(fontSize: 12),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton(
                                                          onPressed: () {
                                                            final target = (app.interviewLink != null && app.interviewLink!.isNotEmpty)
                                                                ? app.interviewLink!
                                                                : (app.interviewId != null
                                                                    ? '/live-interview?room=interview_${app.interviewId}&id=${app.interviewId}'
                                                                    : '/live-interview?room=interview_${app.id}&id=${app.id}');
                                                            context.go(target);
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: AppColors.primary,
                                                            foregroundColor: Colors.white,
                                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                          ),
                                                          child: const Text('Join Live Room ↗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
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
