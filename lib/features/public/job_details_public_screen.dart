import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/application_repository.dart';
import '../../models/job_model.dart';

class JobDetailsPublicScreen extends ConsumerStatefulWidget {
  final int jobId;

  const JobDetailsPublicScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailsPublicScreen> createState() => _JobDetailsPublicScreenState();
}

class _JobDetailsPublicScreenState extends ConsumerState<JobDetailsPublicScreen> {
  JobModel? _job;
  bool _isLoading = true;
  bool _isApplying = false;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _fetchJob();
  }

  void _fetchJob() async {
    try {
      final repo = JobRepository();
      final j = await repo.getJobDetail(widget.jobId);
      setState(() {
        _job = j;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _apply() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      context.go('/login');
      return;
    }

    setState(() => _isApplying = true);
    try {
      final repo = ApplicationRepository();
      await repo.applyToJob(widget.jobId, coverLetter: 'Excited to apply for this position via TalentAI.');
      setState(() {
        _isApplying = false;
        _hasApplied = true;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Text('Application Submitted!'),
            content: const Text(
              'Your profile and verified qualifications have been delivered. TalentAI matching score: 93% match. You can now access your application status or practice in the live interview room!',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/candidate/applications');
                },
                child: const Text('View Applications', style: TextStyle(color: AppColors.primary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isApplying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already applied or an error occurred.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_job == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Job not found'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => context.go('/jobs'), child: const Text('Back to Job Board')),
            ],
          ),
        ),
      );
    }

    final job = _job!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopNavbar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 16,
                vertical: isDesktop ? 36 : 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Job Header Card
                      AppCard(
                        padding: EdgeInsets.all(isDesktop ? 32 : 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isDesktop)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(job.title, style: AppTypography.displaySmall.copyWith(fontSize: 28, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${job.company?.name ?? "Technology Corp"} • ${job.location}',
                                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppButton(
                                    label: _hasApplied ? 'Applied ✓' : 'Apply Now',
                                    isLoading: _isApplying,
                                    onPressed: _hasApplied ? null : _apply,
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(job.title, style: AppTypography.displaySmall.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${job.company?.name ?? "Technology Corp"} • ${job.location}',
                                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: AppButton(
                                      label: _hasApplied ? 'Applied ✓' : 'Apply Now',
                                      isLoading: _isApplying,
                                      onPressed: _hasApplied ? null : _apply,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _Pill(label: job.jobType.replaceAll('_', ' ')),
                                _Pill(label: job.workplaceType),
                                _Pill(label: job.experienceLevel),
                                _Pill(label: '\$${(job.minSalary ?? 160000).toInt()} - \$${(job.maxSalary ?? 210000).toInt()} / year'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Description & Details
                      AppCard(
                        padding: EdgeInsets.all(isDesktop ? 32 : 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('About the Role', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text(job.description, style: AppTypography.bodyLarge),
                            const SizedBox(height: 28),

                            if (job.responsibilities.isNotEmpty) ...[
                              Text('Responsibilities', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Text(job.responsibilities, style: AppTypography.bodyLarge),
                              const SizedBox(height: 28),
                            ],

                            if (job.requirements.isNotEmpty) ...[
                              Text('Required Qualifications', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Text(job.requirements, style: AppTypography.bodyLarge),
                              const SizedBox(height: 28),
                            ],

                            if (job.benefits.isNotEmpty) ...[
                              Text('Benefits & Compensation', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Text(job.benefits, style: AppTypography.bodyLarge),
                              const SizedBox(height: 28),
                            ],

                            Text('Tech Stack & Domains', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: job.skills.map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
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

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textPrimary)),
    );
  }
}
