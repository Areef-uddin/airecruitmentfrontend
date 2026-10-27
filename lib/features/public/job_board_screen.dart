import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../providers/job_provider.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/application_repository.dart';

class JobBoardScreen extends ConsumerStatefulWidget {
  const JobBoardScreen({super.key});

  @override
  ConsumerState<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends ConsumerState<JobBoardScreen> {
  final _searchController = TextEditingController();
  String _selectedWorkplace = 'ALL';
  Set<int> _appliedJobIds = {};

  @override
  void initState() {
    super.initState();
    _fetchAppliedJobs();
  }

  void _fetchAppliedJobs() async {
    final user = ref.read(authProvider).user;
    if (user != null && user.isCandidate) {
      try {
        final apps = await ApplicationRepository().getApplications();
        if (mounted) {
          setState(() {
            _appliedJobIds = apps.map((a) => a.jobId).whereType<int>().toSet();
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsListProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopNavbar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 16,
                vertical: isDesktop ? 40 : 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover Next-Gen Tech Roles',
                        style: AppTypography.displaySmall.copyWith(fontSize: isDesktop ? 32 : 24),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Browse verified opportunities with transparent AI matching criteria and direct interviews.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 24),

                      // Search & Filter Bar
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              hint: 'Search by role, stack (Flutter, Python, AI), or company...',
                              controller: _searchController,
                              prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Filter chips
                      Wrap(
                        spacing: 8,
                        children: ['ALL', 'REMOTE', 'HYBRID', 'ONSITE'].map((w) {
                          final isSel = _selectedWorkplace == w;
                          return ChoiceChip(
                            label: Text(w),
                            selected: isSel,
                            onSelected: (_) => setState(() => _selectedWorkplace = w),
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfaceLight,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),

                      jobsAsync.when(
                        loading: () => const Center(
                          child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primary)),
                        ),
                        error: (e, _) => AppCard(child: Text('Unable to load jobs: $e')),
                        data: (jobs) {
                          final query = _searchController.text.toLowerCase();
                          final filtered = jobs.where((j) {
                            final matchesQuery = query.isEmpty ||
                                j.title.toLowerCase().contains(query) ||
                                (j.company?.name.toLowerCase().contains(query) ?? false) ||
                                j.skills.any((s) => s.toLowerCase().contains(query));
                            final matchesWorkplace = _selectedWorkplace == 'ALL' || j.workplaceType == _selectedWorkplace;
                            return matchesQuery && matchesWorkplace;
                          }).toList();

                          if (filtered.isEmpty) {
                            return const AppCard(
                              padding: EdgeInsets.all(40),
                              child: Center(child: Text('No matching job openings found.')),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final job = filtered[index];
                              final hasApplied = _appliedJobIds.contains(job.id);

                              return AppCard(
                                onTap: () => context.go('/jobs/${job.id}'),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.business_outlined, color: AppColors.primary, size: 28),
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  job.title,
                                                  style: AppTypography.titleLarge.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              if (hasApplied) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(100),
                                                    border: Border.all(color: AppColors.success.withOpacity(0.5)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check_circle, color: AppColors.success, size: 12),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Applied',
                                                        style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accentCyan.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                child: Text(
                                                  job.workplaceType,
                                                  style: const TextStyle(fontSize: 11, color: AppColors.accentCyan, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${job.company?.name ?? "Technology Corp"} • ${job.location} • \$${(job.minSalary ?? 160000).toInt()} - \$${(job.maxSalary ?? 210000).toInt()} • 📅 ${job.createdAt != null ? "${job.createdAt!.day.toString().padLeft(2, '0')}/${job.createdAt!.month.toString().padLeft(2, '0')}/${job.createdAt!.year}" : "Recently"}',
                                            style: AppTypography.bodySmall,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            job.description,
                                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: job.skills.take(5).map((s) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceLight,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppColors.border),
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
            ),
          ),
        ],
      ),
    );
  }
}
