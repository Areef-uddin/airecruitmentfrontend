import 'dart:typed_data';
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

import 'package:file_picker/file_picker.dart';

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
    _checkAppliedStatus();
  }

  void _checkAppliedStatus() async {
    final user = ref.read(authProvider).user;
    if (user != null && user.isCandidate) {
      try {
        final apps = await ApplicationRepository().getApplications();
        if (mounted && apps.any((a) => a.jobId == widget.jobId)) {
          setState(() => _hasApplied = true);
        }
      } catch (_) {}
    }
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

  void _showApplyDialog() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      context.go('/login');
      return;
    }

    Uint8List? pickedResumeBytes;
    String? pickedResumeName;
    int? pickedResumeSize;
    final coverController = TextEditingController(text: 'Excited to apply for this position via TalentAI.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF131522),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Apply to ${_job?.title ?? "Role"}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resume / CV Attachment:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: pickedResumeName != null ? AppColors.accentEmerald : AppColors.primary, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickedResumeName ?? 'Primary Account Resume',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  pickedResumeName != null
                                      ? '${((pickedResumeSize ?? 0) / 1024).toStringAsFixed(1)} KB • Attached'
                                      : 'Will submit verified CV from your profile',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final files = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'docx', 'doc'],
                              );
                              if (files.isNotEmpty) {
                                final f = files.first;
                                final b = await f.readAsBytes();
                                setDialogState(() {
                                  pickedResumeBytes = b;
                                  pickedResumeName = f.name;
                                  pickedResumeSize = f.lengthSync() ?? b.length;
                                });
                              }
                            },
                            icon: const Icon(Icons.upload_file, size: 16, color: AppColors.primary),
                            label: Text(pickedResumeName != null ? 'Change' : 'Upload PDF', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Brief Cover Note / Pitch:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: coverController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1A1D2E),
                        hintText: 'Share key achievements or why you are a great match...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isApplying = true);
                  try {
                    final repo = ApplicationRepository();
                    await repo.applyToJob(
                      widget.jobId,
                      coverLetter: coverController.text.trim(),
                      resumeBytes: pickedResumeBytes,
                      resumeFileName: pickedResumeName,
                    );
                    setState(() {
                      _isApplying = false;
                      _hasApplied = true;
                    });
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (alertCtx) => AlertDialog(
                          backgroundColor: const Color(0xFF131522),
                          title: const Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.accentEmerald),
                              SizedBox(width: 8),
                              Text('Application Delivered!'),
                            ],
                          ),
                          content: const Text(
                            'Your resume and technical profile have been successfully submitted to the recruiter. AI Nora will tailor the technical screening interview to your exact resume projects!',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(alertCtx);
                                context.go('/candidate/applications');
                              },
                              child: const Text('View Applications', style: TextStyle(color: AppColors.primary)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(alertCtx),
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
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Submit Application'),
              ),
            ],
          );
        },
      ),
    );
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
                                    onPressed: _hasApplied ? null : _showApplyDialog,
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
                                      onPressed: _hasApplied ? null : _showApplyDialog,
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
                                _Pill(label: '📅 Posted: ${job.createdAt != null ? "${job.createdAt!.day.toString().padLeft(2, '0')}/${job.createdAt!.month.toString().padLeft(2, '0')}/${job.createdAt!.year}" : "Recently"}'),
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
