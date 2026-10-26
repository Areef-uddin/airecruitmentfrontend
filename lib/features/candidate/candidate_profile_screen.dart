import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/sidebar_navigation.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/config/api_config.dart';

class CandidateProfileScreen extends ConsumerStatefulWidget {
  const CandidateProfileScreen({super.key});

  @override
  ConsumerState<CandidateProfileScreen> createState() => _CandidateProfileScreenState();
}

class _CandidateProfileScreenState extends ConsumerState<CandidateProfileScreen> {
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _expController = TextEditingController();
  final _salaryController = TextEditingController();
  final _skillInputController = TextEditingController();

  List<String> _skills = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void _fetchProfile() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get(ApiConfig.candidateMe);
      if (res.data != null) {
        setState(() {
          _headlineController.text = res.data['headline'] ?? _headlineController.text;
          _bioController.text = res.data['bio'] ?? _bioController.text;
          _locationController.text = res.data['location'] ?? _locationController.text;
          if (res.data['years_of_experience'] != null) {
            _expController.text = res.data['years_of_experience'].toString();
          }
          if (res.data['expected_salary'] != null) {
            _salaryController.text = res.data['expected_salary'].toString();
          }
          if (res.data['skills'] != null && res.data['skills'] is List) {
            _skills = (res.data['skills'] as List)
                .map((s) => s['skill_name']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
        });
      }
    } catch (_) {}
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final dio = ApiClient().dio;
      await dio.patch(
        ApiConfig.candidateMe,
        data: {
          'headline': _headlineController.text.trim(),
          'bio': _bioController.text.trim(),
          'location': _locationController.text.trim(),
          'years_of_experience': double.tryParse(_expController.text) ?? 5.0,
          'expected_salary': double.tryParse(_salaryController.text) ?? 150000.0,
        },
      );
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addSkill() async {
    final skill = _skillInputController.text.trim();
    if (skill.isEmpty || _skills.contains(skill)) return;

    setState(() {
      _skills.add(skill);
      _skillInputController.clear();
    });

    try {
      final dio = ApiClient().dio;
      await dio.post(
        ApiConfig.candidateSkills,
        data: {
          'skill_name': skill,
          'years_of_experience': 3.0,
        },
      );
    } catch (_) {}
  }

  void _removeSkill(String skill) async {
    setState(() {
      _skills.remove(skill);
    });
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
                  SidebarNavigation(user: user, currentRoute: '/candidate/profile'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile & Technical Qualifications',
                              style: AppTypography.displaySmall.copyWith(fontSize: isDesktop ? 26 : 22),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Keep your experience updated so our AI matching engine highlights your strengths.',
                              style: AppTypography.bodyMedium,
                            ),
                            const SizedBox(height: 24),

                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: isDesktop ? 36 : 28,
                                        backgroundColor: AppColors.primary,
                                        child: Text(
                                          user?.fullName.isNotEmpty ?? false ? user!.fullName[0].toUpperCase() : 'A',
                                          style: TextStyle(fontSize: isDesktop ? 28 : 22, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(user?.fullName ?? 'Candidate Profile', style: AppTypography.titleLarge.copyWith(fontSize: isDesktop ? 20 : 16)),
                                            Text(user?.email ?? '', style: AppTypography.bodySmall),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.accentEmerald.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                '✓ Verified Engineering Profile',
                                                style: TextStyle(color: AppColors.accentEmerald, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 20),

                                  AppTextField(
                                    label: 'Professional Headline',
                                    controller: _headlineController,
                                  ),
                                  const SizedBox(height: 16),

                                  AppTextField(
                                    label: 'Executive Bio & Summary',
                                    controller: _bioController,
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 16),

                                  if (isDesktop)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppTextField(
                                            label: 'Location',
                                            controller: _locationController,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: AppTextField(
                                            label: 'Years of Experience',
                                            controller: _expController,
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    AppTextField(
                                      label: 'Location',
                                      controller: _locationController,
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      label: 'Years of Experience',
                                      controller: _expController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                  const SizedBox(height: 16),

                                  AppTextField(
                                    label: 'Target Base Salary (USD)',
                                    controller: _salaryController,
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 24),

                                  // Verified Skills Tag Cloud
                                  Text('Core Skills & Tech Stack', style: AppTypography.labelLarge),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          hint: 'Add a new skill (e.g. Docker, GraphQL, Kubernetes)...',
                                          controller: _skillInputController,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: _addSkill,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        ),
                                        child: const Text('Add Skill'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _skills.map((s) {
                                      return Chip(
                                        label: Text(s),
                                        backgroundColor: AppColors.surfaceLight,
                                        deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.textTertiary),
                                        onDeleted: () => _removeSkill(s),
                                        side: const BorderSide(color: AppColors.border),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 32),

                                  Align(
                                    alignment: isDesktop ? Alignment.centerRight : Alignment.center,
                                    child: AppButton(
                                      label: 'Save Profile Changes',
                                      isLoading: _isLoading,
                                      onPressed: _saveProfile,
                                    ),
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
          ),
        ],
      ),
    );
  }
}
