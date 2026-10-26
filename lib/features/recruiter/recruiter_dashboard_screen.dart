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
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../repositories/recruiter_repository.dart';
import '../../repositories/interview_repository.dart';
import '../../models/interview_model.dart';

class RecruiterDashboardScreen extends ConsumerStatefulWidget {
  const RecruiterDashboardScreen({super.key});

  @override
  ConsumerState<RecruiterDashboardScreen> createState() => _RecruiterDashboardScreenState();
}

class _RecruiterDashboardScreenState extends ConsumerState<RecruiterDashboardScreen> {
  RecruiterDashboardData? _dashboardData;
  List<InterviewModel> _interviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  void _fetchDashboard() async {
    try {
      final repo = RecruiterRepository();
      final data = await repo.getDashboardData();
      final interviews = await InterviewRepository().getInterviews();
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _interviews = interviews;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openInstantMeetingDialog() {
    final titleController = TextEditingController(text: 'Instant Live Screening');
    final roomController = TextEditingController(text: 'meet_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}');
    int? selectedCandidateId;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131522),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.video_call, color: Color(0xFFD946EF)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Start Instant Live Screening', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create an instant interview room. Candidate will automatically receive an invitation notification with the exact room link.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Meeting Title',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFF1A1C2C),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: roomController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Room Code / Name',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFF1A1C2C),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Invite Priority Candidate (Optional):', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        value: selectedCandidateId,
                        dropdownColor: const Color(0xFF1A1C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1A1C2C),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        hint: const Text('Open Room (Share link manually)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Open Room (Share link manually)', style: TextStyle(color: Colors.white70)),
                          ),
                          ...(_dashboardData?.recentApplicants ?? []).map((a) {
                            return DropdownMenuItem<int?>(
                              value: a['id'] as int?,
                              child: Text('${a['candidate_name']} (${a['job_title']})', style: const TextStyle(color: Colors.white)),
                            );
                          }),
                        ],
                        onChanged: (val) => setDialogState(() => selectedCandidateId = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          final chosenRoom = roomController.text.trim();
                          final chosenTitle = titleController.text.trim();

                          try {
                            if (selectedCandidateId != null) {
                              final interview = await InterviewRepository().scheduleInterview(
                                candidateId: selectedCandidateId,
                                title: chosenTitle,
                                room: chosenRoom,
                              );
                              Navigator.pop(ctx);
                              _fetchDashboard();
                              final target = interview.meetingLink.isNotEmpty
                                  ? interview.meetingLink
                                  : '/live-interview?room=$chosenRoom&id=${interview.id}';
                              if (mounted) context.go(target);
                            } else {
                              Navigator.pop(ctx);
                              context.go('/live-interview?room=$chosenRoom');
                            }
                          } catch (e) {
                            Navigator.pop(ctx);
                            context.go('/live-interview?room=$chosenRoom');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD946EF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.videocam, size: 16),
                  label: const Text('Start Meeting Now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final metrics = {
      'total_jobs': _dashboardData?.metrics['total_jobs'] ?? 0,
      'active_jobs': _dashboardData?.metrics['active_jobs'] ?? 0,
      'total_applications': _dashboardData?.metrics['total_applications'] ?? 0,
      'interviews_scheduled': _interviews.length,
      'shortlisted_candidates': _dashboardData?.metrics['shortlisted_candidates'] ?? 0,
      'offers_extended': _dashboardData?.metrics['offers_extended'] ?? 0,
    };

    final pipeline = (_dashboardData?.pipeline != null && _dashboardData!.pipeline.isNotEmpty)
        ? _dashboardData!.pipeline
        : [
            {'stage': 'Submitted', 'count': 0, 'color': '#6366F1'},
            {'stage': 'Screening', 'count': 0, 'color': '#06B6D4'},
            {'stage': 'Shortlisted', 'count': 0, 'color': '#8B5CF6'},
            {'stage': 'Interview', 'count': _interviews.length, 'color': '#EC4899'},
            {'stage': 'Offer', 'count': 0, 'color': '#10B981'},
          ];

    final applicants = _dashboardData?.recentApplicants ?? [];

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
                  SidebarNavigation(user: user, currentRoute: '/recruiter/dashboard'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Action Header (Responsive)
                        if (isDesktop)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Recruitment Overview', style: AppTypography.displaySmall.copyWith(fontSize: 26)),
                                  const SizedBox(height: 4),
                                  Text('Real-time pipeline metrics and AI screening progress.', style: AppTypography.bodySmall),
                                ],
                              ),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _openInstantMeetingDialog,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFD946EF),
                                      side: const BorderSide(color: Color(0xFFD946EF)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.video_call, size: 18),
                                    label: const Text('Start Instant Meeting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  const SizedBox(width: 12),
                                  AppButton(
                                    label: 'Post New Job',
                                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                                    onPressed: () => context.go('/recruiter/create-job'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recruitment Overview', style: AppTypography.displaySmall.copyWith(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text('Real-time pipeline metrics and AI screening progress.', style: AppTypography.bodySmall),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _openInstantMeetingDialog,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFD946EF),
                                      side: const BorderSide(color: Color(0xFFD946EF)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.video_call, size: 18),
                                    label: const Text('Start Instant Meeting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  AppButton(
                                    label: 'Post New Job',
                                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                    onPressed: () => context.go('/recruiter/create-job'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // ACTIVE SCHEDULED CANDIDATE INTERVIEWS SECTION (ALWAYS VISIBLE)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Scheduled Candidate AI Interviews',
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 20 : 16,
                              ),
                            ),
                            if (_interviews.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                ),
                                child: Text(
                                  '${_interviews.length} Scheduled',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_interviews.isEmpty)
                          AppCard(
                            child: Padding(
                              padding: EdgeInsets.all(isDesktop ? 24 : 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD946EF).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.25)),
                                    ),
                                    child: const Icon(Icons.event_busy, color: Color(0xFFD946EF), size: 26),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'No Scheduled Interviews',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'You currently have no candidate interviews scheduled. When you schedule an interview or invite a candidate, it will appear here with an instant room link.',
                                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 8,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: _openInstantMeetingDialog,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFD946EF),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.video_call, size: 16),
                                              label: const Text('Start Instant Screening', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () => context.go('/recruiter/pipeline'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(color: Color(0xFF2E324D)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.people_outline, size: 16),
                                              label: const Text('View Pipeline Candidates', style: TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                        ),
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
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final it = _interviews[idx];
                              final roomTarget = it.meetingLink.isNotEmpty
                                  ? (it.meetingLink.contains('id=') ? it.meetingLink : '${it.meetingLink}&id=${it.id}')
                                  : '/live-interview?room=interview_${it.id}&id=${it.id}';

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161826),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.35)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: const Color(0xFFD946EF).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.videocam, color: Color(0xFFD946EF), size: 22),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(it.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Candidate: ${it.application?.candidate?.fullName ?? it.application?.candidate?.email ?? "Candidate"} • Room: interview_${it.id}',
                                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                              ),
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
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.copy, size: 14),
                                            label: const Text('Share Link', style: TextStyle(fontSize: 11)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => context.go(roomTarget),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.login, size: 16),
                                            label: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (!isDesktop) ...[
                                      const SizedBox(height: 12),
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
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              ),
                                              icon: const Icon(Icons.copy, size: 13),
                                              label: const Text('Share Link', style: TextStyle(fontSize: 11)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => context.go(roomTarget),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.login, size: 14),
                                              label: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
                        const SizedBox(height: 24),

                        // METRIC CARDS (Responsive Grid)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
                            final cardWidth = (constraints.maxWidth - ((cols - 1) * 14)) / cols;

                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                _MetricCard(
                                  width: cardWidth,
                                  title: 'Active Roles',
                                  value: '${metrics['active_jobs'] ?? 3}',
                                  icon: Icons.work_outline,
                                  accentColor: AppColors.primary,
                                ),
                                _MetricCard(
                                  width: cardWidth,
                                  title: 'Total Applicants',
                                  value: '${metrics['total_applications'] ?? 14}',
                                  icon: Icons.people_outline,
                                  accentColor: AppColors.accentCyan,
                                ),
                                _MetricCard(
                                  width: cardWidth,
                                  title: 'Interviews Active',
                                  value: '${metrics['interviews_scheduled'] ?? 4}',
                                  icon: Icons.videocam_outlined,
                                  accentColor: AppColors.secondary,
                                ),
                                _MetricCard(
                                  width: cardWidth,
                                  title: 'Avg AI Match',
                                  value: '91.8%',
                                  icon: Icons.auto_awesome,
                                  accentColor: AppColors.accentEmerald,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // PIPELINE FUNNEL CARDS (Responsive LayoutBuilder)
                        Text('Recruitment Pipeline', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 650;
                              if (!isNarrow) {
                                return Row(
                                  children: pipeline.map((item) {
                                    return Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['stage'] ?? '',
                                              style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${item['count'] ?? 0}',
                                              style: AppTypography.titleLarge.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              }

                              final itemWidth = (constraints.maxWidth - 8) / 2;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: pipeline.map((item) {
                                  return Container(
                                    width: itemWidth,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['stage'] ?? '',
                                          style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item['count'] ?? 0}',
                                          style: AppTypography.titleLarge.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        // RECENT APPLICANTS TABLE (Responsive)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Priority Applicants & AI Scores', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, fontSize: isDesktop ? 20 : 16)),
                            TextButton(
                              onPressed: () => context.go('/recruiter/pipeline'),
                              child: const Text('View Full Pipeline ↗', style: TextStyle(color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (applicants.isEmpty)
                          AppCard(
                            padding: const EdgeInsets.all(28),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.people_outline, color: Color(0xFF94A3B8), size: 30),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No Candidates In Pipeline Yet',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'When candidates apply to your active jobs, their profiles and AI match rankings will appear here.',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: applicants.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                              final app = applicants[index];

                              if (isDesktop) {
                                return Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary.withOpacity(0.2),
                                        child: Text(
                                          app['candidate_name']?[0] ?? 'C',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(app['candidate_name'] ?? '', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                            Text(app['job_title'] ?? '', style: AppTypography.bodySmall),
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
                                              '${(app['ai_match_score'] as num?)?.toInt() ?? 93}%',
                                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      StatusBadge(status: app['status'] ?? 'SUBMITTED'),
                                      const SizedBox(width: 14),
                                      ElevatedButton(
                                        onPressed: () => context.go('/live-interview'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.surfaceElevated,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        child: const Text('Live Review', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppColors.primary.withOpacity(0.2),
                                          child: Text(
                                            app['candidate_name']?[0] ?? 'C',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(app['candidate_name'] ?? '', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                                              Text(app['job_title'] ?? '', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(100),
                                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.auto_awesome, size: 11, color: AppColors.primary),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${(app['ai_match_score'] as num?)?.toInt() ?? 93}%',
                                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(status: app['status'] ?? 'SUBMITTED'),
                                        const Spacer(),
                                        ElevatedButton(
                                          onPressed: () => context.go('/live-interview'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.surfaceElevated,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          child: const Text('Live Review', style: TextStyle(fontSize: 10)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary, fontSize: 13)),
              Icon(icon, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.displaySmall.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
