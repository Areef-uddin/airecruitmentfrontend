import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/sidebar_navigation.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/status_badge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';

class RecruiterJobsScreen extends ConsumerWidget {
  const RecruiterJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final myJobsAsync = ref.watch(myPostedJobsProvider);

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
                  SidebarNavigation(user: user, currentRoute: '/recruiter/jobs'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDesktop)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Company Job Postings', style: AppTypography.displaySmall.copyWith(fontSize: 26)),
                                  const SizedBox(height: 4),
                                  Text('Manage published roles, inspect applicant volume, and edit requirements.', style: AppTypography.bodySmall),
                                ],
                              ),
                              AppButton(
                                label: 'Post New Role',
                                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                onPressed: () => context.go('/recruiter/create-job'),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Company Job Postings', style: AppTypography.displaySmall.copyWith(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text('Manage published roles, inspect applicant volume, and edit requirements.', style: AppTypography.bodySmall),
                              const SizedBox(height: 12),
                              AppButton(
                                label: 'Post New Role',
                                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                onPressed: () => context.go('/recruiter/create-job'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        myJobsAsync.when(
                          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary))),
                          error: (e, _) => AppCard(child: Text('Error: $e')),
                          data: (jobs) {
                            if (jobs.isEmpty) {
                              return AppCard(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.work_outline, size: 48, color: AppColors.textTertiary),
                                      const SizedBox(height: 12),
                                      Text('No jobs posted yet', style: AppTypography.titleMedium),
                                      const SizedBox(height: 16),
                                      AppButton(
                                        label: 'Create Your First Job',
                                        onPressed: () => context.go('/recruiter/create-job'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: jobs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final job = jobs[index];
                                if (!isDesktop) {
                                  return AppCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(job.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${job.location} • ${job.jobType} • ${job.workplaceType} • \$${(job.minSalary ?? 160000).toInt()} - \$${(job.maxSalary ?? 200000).toInt()}',
                                          style: AppTypography.bodySmall,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            StatusBadge(status: job.status),
                                            Text('${job.viewsCount} views • ${job.applicationsCount} applicants', style: AppTypography.bodySmall),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return AppCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(job.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${job.location} • ${job.jobType} • ${job.workplaceType} • \$${(job.minSalary ?? 160000).toInt()} - \$${(job.maxSalary ?? 200000).toInt()}',
                                              style: AppTypography.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          StatusBadge(status: job.status),
                                          const SizedBox(height: 6),
                                          Text('${job.viewsCount} views • ${job.applicationsCount} applicants', style: AppTypography.bodySmall),
                                        ],
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
