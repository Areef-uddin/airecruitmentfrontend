import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/sidebar_navigation.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/recruiter_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/interview_repository.dart';
import '../../models/job_model.dart';

class RecruiterCandidateSearchScreen extends ConsumerStatefulWidget {
  const RecruiterCandidateSearchScreen({super.key});

  @override
  ConsumerState<RecruiterCandidateSearchScreen> createState() => _RecruiterCandidateSearchScreenState();
}

class _RecruiterCandidateSearchScreenState extends ConsumerState<RecruiterCandidateSearchScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _candidates = [];
  bool _isLoading = true;
  List<JobModel> _recruiterJobs = [];
  final Set<int> _invitedCandidateIds = {};
  final Map<int, String> _candidateMeetingLinks = {};

  final InterviewRepository _interviewRepo = InterviewRepository();
  final JobRepository _jobRepo = JobRepository();

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _search();
  }

  void _loadJobs() async {
    try {
      final jobs = await _jobRepo.getJobs(mineOnly: true);
      if (mounted) setState(() => _recruiterJobs = jobs);
    } catch (_) {}
  }

  void _search() async {
    setState(() => _isLoading = true);
    try {
      final repo = RecruiterRepository();
      final res = await repo.searchCandidates(query: _searchController.text.trim());
      setState(() {
        _candidates = res;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _openInviteDialog(dynamic c) {
    int? selectedJobId = _recruiterJobs.isNotEmpty ? _recruiterJobs.first.id : null;
    final titleController = TextEditingController(text: 'AI Technical Screening - ${c['name'] ?? "Candidate"}');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E2030),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.video_call, color: Color(0xFFD946EF), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Invite ${c['name'] ?? "Candidate"} to Interview',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Position for Interview:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 6),
                  if (_recruiterJobs.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedJobId,
                      dropdownColor: const Color(0xFF1A1C2B),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF13141F),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2E324D))),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: _recruiterJobs.map((j) {
                        return DropdownMenuItem<int>(
                          value: j.id,
                          child: Text(j.title, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedJobId = val),
                    )
                  else
                    const Text('No posted jobs found. An AI assessment interview will be scheduled.', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                  const SizedBox(height: 16),

                  const Text('Interview Session Title:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF13141F),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2E324D))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF8B5CF6)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'An automated invitation notification will be sent directly to the candidate\'s dashboard with an instant "Join Meeting" link.',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final interview = await _interviewRepo.scheduleInterview(
                            candidateId: c['user_id'] ?? c['id'],
                            jobId: selectedJobId,
                            title: titleController.text.trim(),
                          );
                          Navigator.pop(ctx);

                          if (mounted) {
                            final target = interview.meetingLink.isNotEmpty
                                ? (interview.meetingLink.contains('id=') ? interview.meetingLink : '${interview.meetingLink}&id=${interview.id}')
                                : '/live-interview?room=interview_${interview.id}&id=${interview.id}';

                            final candKey = (c['user_id'] ?? c['id']) as int?;
                            setState(() {
                              if (candKey != null) {
                                _invitedCandidateIds.add(candKey);
                                _candidateMeetingLinks[candKey] = target;
                              }
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Text('Interview invitation sent to ${c['name']}! Room created: interview_${interview.id}'),
                                action: SnackBarAction(
                                  label: 'Join Room',
                                  textColor: Colors.white,
                                  onPressed: () => context.go(target),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: AppColors.accentRose, content: Text('Error: $e')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD946EF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 16),
                label: const Text('Send Invitation'),
              ),
            ],
          );
        },
      ),
    );
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
                  SidebarNavigation(user: user, currentRoute: '/recruiter/candidates'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Talent Sourcing & Search', style: AppTypography.displaySmall.copyWith(fontSize: isDesktop ? 26 : 22)),
                        const SizedBox(height: 4),
                        Text('Query real candidates by technical domains, verified skills, and invite them directly to live screening.', style: AppTypography.bodySmall),
                        const SizedBox(height: 20),

                        // Search Input (Responsive)
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  hint: 'Search by skill (e.g. Flutter, Python, Django, Cloud Architecture)...',
                                  controller: _searchController,
                                  prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                                  onChanged: (_) => _search(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _search,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.tune, size: 18),
                                label: const Text('Search'),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              AppTextField(
                                hint: 'Search by skill (Flutter, Python, AI)...',
                                controller: _searchController,
                                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                                onChanged: (_) => _search(),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _search,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.tune, size: 16),
                                  label: const Text('Search Candidates'),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        if (_isLoading)
                          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)))
                        else if (_candidates.isEmpty)
                          const AppCard(child: Center(child: Text('No matching candidates found.')))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _candidates.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final c = _candidates[index];
                              final skills = (c['skills'] is List) ? (c['skills'] as List) : ['Python', 'Flutter', 'Dart'];

                              return AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: isDesktop ? 26 : 22,
                                          backgroundColor: AppColors.primary.withOpacity(0.2),
                                          child: Text(
                                            c['name'] != null && c['name'].isNotEmpty ? c['name'][0].toUpperCase() : 'C',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: isDesktop ? 18 : 16, color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (isDesktop)
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(c['name'] ?? '', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                                    ),
                                                    Builder(
                                                      builder: (context) {
                                                        final candKey = (c['user_id'] ?? c['id']) as int?;
                                                        final isInvited = candKey != null && _invitedCandidateIds.contains(candKey);
                                                        final target = (candKey != null ? _candidateMeetingLinks[candKey] : null) ?? '/live-interview';

                                                        if (isInvited) {
                                                          return Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
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
                                                              const SizedBox(width: 8),
                                                              OutlinedButton.icon(
                                                                onPressed: () => _openInviteDialog(c),
                                                                style: OutlinedButton.styleFrom(
                                                                  foregroundColor: const Color(0xFFD946EF),
                                                                  side: const BorderSide(color: Color(0xFFD946EF)),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                                ),
                                                                icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFD946EF)),
                                                                label: const Text('Re-invite', style: TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold)),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              ElevatedButton.icon(
                                                                onPressed: () => context.go(target),
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: const Color(0xFF10B981),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                                ),
                                                                icon: const Icon(Icons.login, size: 14, color: Colors.white),
                                                                label: const Text('Join Room', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                              ),
                                                            ],
                                                          );
                                                        }

                                                        return ElevatedButton.icon(
                                                          onPressed: () => _openInviteDialog(c),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: const Color(0xFFD946EF),
                                                            foregroundColor: Colors.white,
                                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                          ),
                                                          icon: const Icon(Icons.video_call, size: 16),
                                                          label: const Text('Invite to Interview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                )
                                              else
                                                Text(c['name'] ?? '', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${c['headline'] ?? "Software Engineer"} • ${c['location'] ?? "Remote"} • ${c['years_of_experience'] ?? 3} yrs exp',
                                                style: AppTypography.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      c['ai_summary'] ?? 'Specialized engineering background with solid system architecture capabilities.',
                                      style: AppTypography.bodySmall.copyWith(color: const Color(0xFFCBD5E1)),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: skills.map((s) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceLight,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Text(s.toString(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        );
                                      }).toList(),
                                    ),
                                    if (!isDesktop) ...[
                                      Builder(
                                        builder: (context) {
                                          final candKey = (c['user_id'] ?? c['id']) as int?;
                                          final isInvited = candKey != null && _invitedCandidateIds.contains(candKey);
                                          final target = (candKey != null ? _candidateMeetingLinks[candKey] : null) ?? '/live-interview';

                                          if (isInvited) {
                                            return Column(
                                              children: [
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: () => _openInviteDialog(c),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: const Color(0xFFD946EF),
                                                          side: const BorderSide(color: Color(0xFFD946EF)),
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                        ),
                                                        icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFD946EF)),
                                                        label: const Text('Re-invite', style: TextStyle(color: Color(0xFFD946EF), fontSize: 11)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () => context.go(target),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF10B981),
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                        ),
                                                        icon: const Icon(Icons.login, size: 14),
                                                        label: const Text('Join Room', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          }

                                          return Column(
                                            children: [
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _openInviteDialog(c),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFD946EF),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.video_call, size: 16),
                                                  label: const Text('Invite to Interview ↗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
