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
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import '../../core/config/api_config.dart';
import '../../models/application_model.dart';
import '../../repositories/interview_repository.dart';

class RecruiterPipelineScreen extends ConsumerStatefulWidget {
  const RecruiterPipelineScreen({super.key});

  @override
  ConsumerState<RecruiterPipelineScreen> createState() => _RecruiterPipelineScreenState();
}

class _RecruiterPipelineScreenState extends ConsumerState<RecruiterPipelineScreen> {
  List<ApplicationModel> _apps = [];
  bool _isLoading = true;
  String _selectedStage = 'ALL';
  final Set<int> _invitedAppIds = {};
  final Map<int, String> _appMeetingLinks = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    try {
      final repo = ApplicationRepository();
      final list = await repo.getApplications();
      setState(() {
        _apps = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _updateStatus(int appId, String newStatus) async {
    try {
      final repo = ApplicationRepository();
      await repo.updateApplicationStatus(appId, newStatus);
      _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
      }
    } catch (_) {}
  }

  void _scheduleOrReinvite(ApplicationModel app, {bool isReinvite = false}) async {
    try {
      final itRepo = InterviewRepository();
      final it = await itRepo.scheduleInterview(
        applicationId: app.id,
        title: 'AI Technical Interview: ${app.job?.title ?? "Screening"}',
      );
      _updateStatus(app.id, 'INTERVIEW_SCHEDULED');
      final target = it.meetingLink.isNotEmpty
          ? (it.meetingLink.contains('id=') ? it.meetingLink : '${it.meetingLink}&id=${it.id}')
          : '/live-interview?room=interview_${it.id}&id=${it.id}';

      if (mounted) {
        setState(() {
          _invitedAppIds.add(app.id);
          _appMeetingLinks[app.id] = target;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(isReinvite
                ? 'Re-invitation sent to ${app.candidate?.fullName ?? "Candidate"}!'
                : 'Interview invitation sent to ${app.candidate?.fullName ?? "Candidate"}!'),
            action: SnackBarAction(
              label: 'Join Room',
              textColor: Colors.white,
              onPressed: () => context.go(target),
            ),
          ),
        );
      }
    } catch (e) {
      _updateStatus(app.id, 'INTERVIEW_SCHEDULED');
      if (mounted) {
        setState(() => _invitedAppIds.add(app.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(isReinvite
                ? 'Re-invitation processed for candidate.'
                : 'Application moved to Interview stage.'),
            action: SnackBarAction(
              label: 'Open Room',
              textColor: Colors.white,
              onPressed: () => context.go('/live-interview?room=interview_${app.id}&id=${app.id}'),
            ),
          ),
        );
      }
    }
  }

  void _viewEvaluationAndResume(ApplicationModel app) async {
    final candidateName = app.candidate?.fullName ?? 'Candidate';
    final resume = app.resume;
    final parsed = resume != null && resume['parsed_data'] is Map ? resume['parsed_data'] as Map : {};
    final skills = parsed['skills'] is List ? List<String>.from(parsed['skills']) : app.matchedSkills;

    Map<String, dynamic>? interviewDetails;
    if (app.interviewId != null) {
      try {
        final it = await InterviewRepository().getInterview(app.interviewId!);
        interviewDetails = {
          'score': it.aiScore,
          'feedback': it.aiFeedback,
          'status': it.status,
          'transcript': it.aiTranscript,
        };
      } catch (_) {}
    }

    final suitabilityScore = interviewDetails?['score'] ?? app.aiMatchScore ?? 92.0;
    final transcript = interviewDetails?['transcript'] is List ? interviewDetails!['transcript'] as List : [];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131522),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Color(0xFFD946EF), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Resume & AI Nora Evaluation: $candidateName',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nora Suitability Percentage Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2138),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD946EF).withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${suitabilityScore.toInt()}%',
                          style: const TextStyle(color: Color(0xFFD946EF), fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nora AI Role Suitability Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              interviewDetails?['feedback'] ?? app.aiMatchExplanation ?? 'Strong technical proficiency matching job requirements.',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Attached Resume Details
                const Text('Attached Resume & Qualifications:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161826),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resume?['file_name'] ?? 'Candidate_Resume.pdf',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              final rawUrl = resume?['file_url'] ?? resume?['file']?.toString();
                              if (rawUrl != null && rawUrl.isNotEmpty) {
                                final fullUrl = rawUrl.startsWith('http')
                                    ? rawUrl
                                    : '${ApiConfig.liveProductionUrl.replaceAll('/api', '')}$rawUrl';
                                if (kIsWeb) {
                                  html.window.open(fullUrl, '_blank');
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Candidate resume ATS profile loaded below.')),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 13, color: Color(0xFF38BDF8)),
                            label: const Text('View File', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (skills.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: skills.take(8).map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Live Conversation Transcript & Spoken Turns
                const Text('Interview Transcript & Spoken Turns:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (transcript.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161826),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('Interview transcript will appear here as Nora conducts the session.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161826),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: transcript.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (c, i) {
                        final turn = transcript[i];
                        final speaker = turn['speaker']?.toString() ?? 'Interviewer';
                        final text = turn['text']?.toString() ?? '';
                        final isNora = speaker.toLowerCase().contains('nora');

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(isNora ? Icons.smart_toy : Icons.person, size: 16, color: isNora ? const Color(0xFFD946EF) : AppColors.accentCyan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(speaker, style: TextStyle(color: isNora ? const Color(0xFFD946EF) : AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(app.id, 'OFFER');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Extend Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final filtered = _selectedStage == 'ALL'
        ? _apps
        : _apps.where((a) => a.status.toUpperCase() == _selectedStage).toList();

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
                  SidebarNavigation(user: user, currentRoute: '/recruiter/pipeline'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Applicant Pipeline Management', style: AppTypography.displaySmall.copyWith(fontSize: isDesktop ? 26 : 22)),
                        const SizedBox(height: 4),
                        Text('Manage candidate stages, review AI match score explanations, and advance top candidates.', style: AppTypography.bodySmall),
                        const SizedBox(height: 20),

                        // Stage Filter Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            'ALL', 'SUBMITTED', 'SCREENING', 'SHORTLISTED', 'INTERVIEW_SCHEDULED', 'OFFER', 'REJECTED'
                          ].map((stage) {
                            final isSel = _selectedStage == stage;
                            return ChoiceChip(
                              label: Text(stage.replaceAll('_', ' ')),
                              selected: isSel,
                              onSelected: (_) => setState(() => _selectedStage = stage),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceLight,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.textSecondary,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 11,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        if (_isLoading)
                          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)))
                        else if (filtered.isEmpty)
                          const AppCard(
                            padding: EdgeInsets.all(40),
                            child: Center(child: Text('No candidates found in this stage.')),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final app = filtered[index];
                              final candidateName = app.candidate?.fullName ?? 'Candidate';

                              return AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isDesktop)
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: AppColors.primary.withOpacity(0.2),
                                            child: Text(
                                              candidateName.isNotEmpty ? candidateName[0].toUpperCase() : 'C',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(candidateName, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                                Text('Applied for: ${app.job?.title ?? "Full Stack Engineer"}', style: AppTypography.bodySmall),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(100),
                                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${app.aiMatchScore?.toInt() ?? 93}% AI Match',
                                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          StatusBadge(status: app.status),
                                        ],
                                      )
                                    else
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                                child: Text(
                                                  candidateName.isNotEmpty ? candidateName[0].toUpperCase() : 'C',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(candidateName, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                                                    Text('Applied: ${app.job?.title ?? "Role"}', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withOpacity(0.18),
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.auto_awesome, size: 11, color: AppColors.primary),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '${app.aiMatchScore?.toInt() ?? 93}% Match',
                                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              StatusBadge(status: app.status),
                                            ],
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 14),
                                    const Divider(),
                                    const SizedBox(height: 10),

                                    // AI Justification
                                    Text(
                                      'AI Screening Evaluation:',
                                      style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      app.aiMatchExplanation ?? 'Strong technical foundation with relevant skills match.',
                                      style: AppTypography.bodySmall.copyWith(color: const Color(0xFFCBD5E1)),
                                    ),
                                    const SizedBox(height: 14),

                                    // Actions (Responsive Wrap)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.end,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () => _updateStatus(app.id, 'REJECTED'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.accentRose,
                                            side: const BorderSide(color: AppColors.accentRose),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          child: const Text('Reject', style: TextStyle(fontSize: 11)),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            final candId = app.candidate?.id;
                                            if (candId != null) {
                                              context.go('/messages?user_id=$candId');
                                            } else {
                                              context.go('/messages');
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(color: Color(0xFF38BDF8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF38BDF8)),
                                          label: const Text('Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        OutlinedButton(
                                          onPressed: () => _updateStatus(app.id, 'SHORTLISTED'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          child: const Text('Shortlist', style: TextStyle(fontSize: 11)),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _viewEvaluationAndResume(app),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFD946EF),
                                            side: const BorderSide(color: Color(0xFFD946EF)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.assignment_ind_outlined, size: 14, color: Color(0xFFD946EF)),
                                          label: const Text('Resume & Nora Eval', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        if (app.status == 'INTERVIEW_SCHEDULED' || _invitedAppIds.contains(app.id)) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                                                SizedBox(width: 4),
                                                Text('Invited', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () => _scheduleOrReinvite(app, isReinvite: true),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFD946EF),
                                              side: const BorderSide(color: Color(0xFFD946EF)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFD946EF)),
                                            label: const Text('Re-invite', style: TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              final target = _appMeetingLinks[app.id] ?? '/live-interview?room=interview_${app.id}&id=${app.id}';
                                              context.go(target);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.login, size: 14, color: Colors.white),
                                            label: const Text('Join Room', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ] else ...[
                                          ElevatedButton.icon(
                                            onPressed: () => _scheduleOrReinvite(app, isReinvite: false),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD946EF),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.videocam, size: 15, color: Colors.white),
                                            label: const Text('Schedule AI Interview', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
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
