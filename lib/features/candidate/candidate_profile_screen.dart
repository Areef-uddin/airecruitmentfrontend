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
  final _companyController = TextEditingController();
  final _expController = TextEditingController();
  final _salaryController = TextEditingController();
  final _skillInputController = TextEditingController();

  List<Map<String, dynamic>> _skills = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _updatedAt = '';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get(ApiConfig.candidateMe);
      if (res.data != null) {
        final data = res.data;
        setState(() {
          _headlineController.text = data['headline'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _locationController.text = data['location'] ?? '';
          _companyController.text = data['current_company'] ?? '';
          if (data['years_of_experience'] != null) {
            _expController.text = data['years_of_experience'].toString();
          }
          if (data['expected_salary'] != null) {
            _salaryController.text = (data['expected_salary'] as num).toInt().toString();
          }
          if (data['updated_at'] != null) {
            _updatedAt = data['updated_at'].toString().split('T').first;
          }
          if (data['skills'] != null && data['skills'] is List) {
            _skills = (data['skills'] as List).map((s) => {
              'id': s['id'],
              'name': s['skill_name']?.toString() ?? '',
              'years': s['years_experience'] ?? 1.0,
            }).where((s) => (s['name'] as String).isNotEmpty).toList();
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final dio = ApiClient().dio;
      await dio.patch(
        ApiConfig.candidateMe,
        data: {
          'headline': _headlineController.text.trim(),
          'bio': _bioController.text.trim(),
          'location': _locationController.text.trim(),
          'current_company': _companyController.text.trim(),
          'years_of_experience': double.tryParse(_expController.text) ?? 3.0,
          'expected_salary': double.tryParse(_salaryController.text) ?? 120000.0,
        },
      );
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile. Please try again.')),
        );
      }
    }
  }

  Future<void> _addSkill() async {
    final skillName = _skillInputController.text.trim();
    if (skillName.isEmpty) return;

    if (_skills.any((s) => (s['name'] as String).toLowerCase() == skillName.toLowerCase())) {
      _skillInputController.clear();
      return;
    }

    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        ApiConfig.candidateSkills,
        data: {
          'skill_name': skillName,
          'years_experience': 2.0,
          'proficiency': 'INTERMEDIATE',
        },
      );
      setState(() {
        _skills.add({
          'id': res.data['id'],
          'name': skillName,
          'years': 2.0,
        });
        _skillInputController.clear();
      });
    } catch (_) {
      setState(() {
        _skills.add({'name': skillName, 'years': 2.0});
        _skillInputController.clear();
      });
    }
  }

  Future<void> _removeSkill(int index) async {
    final skill = _skills[index];
    final skillId = skill['id'];

    setState(() {
      _skills.removeAt(index);
    });

    if (skillId != null) {
      try {
        final dio = ApiClient().dio;
        await dio.delete('${ApiConfig.candidateSkills}$skillId/');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final fullName = user != null
        ? '${user.firstName} ${user.lastName}'.trim().isNotEmpty
            ? '${user.firstName} ${user.lastName}'.trim()
            : user.username
        : 'Candidate';

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
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Profile & Skills Management',
                                      style: AppTypography.displaySmall.copyWith(fontSize: isDesktop ? 28 : 22),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Manage your registration details, technical qualifications, and target compensation.',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                                AppButton(
                                  label: 'Save Profile',
                                  icon: const Icon(Icons.check, size: 18, color: Colors.white),
                                  isLoading: _isSaving,
                                  onPressed: _saveProfile,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            if (_isLoading)
                              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primary)))
                            else ...[
                              // Account & Registration Details Card
                              AppCard(
                                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: isDesktop ? 34 : 26,
                                          backgroundColor: AppColors.primary,
                                          child: Text(
                                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C',
                                            style: TextStyle(fontSize: isDesktop ? 26 : 20, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(fullName, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.success.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text('Verified', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(user?.email ?? '', style: AppTypography.bodySmall),
                                              if (_updatedAt.isNotEmpty)
                                                Text('📅 Last Synced: $_updatedAt', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(),
                                    const SizedBox(height: 16),

                                    // Registration Data summary pills
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 10,
                                      children: [
                                        _buildInfoChip(Icons.person_outline, 'Username', user?.username ?? ''),
                                        _buildInfoChip(Icons.email_outlined, 'Email', user?.email ?? ''),
                                        _buildInfoChip(Icons.badge_outlined, 'Role', user?.role ?? 'CANDIDATE'),
                                        if (user != null && user.phoneNumber.isNotEmpty)
                                          _buildInfoChip(Icons.phone_outlined, 'Phone', user.phoneNumber),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Professional & Technical Details Card
                              AppCard(
                                padding: EdgeInsets.all(isDesktop ? 28 : 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Professional Experience & Headline', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),

                                    AppTextField(
                                      label: 'Headline / Role Title',
                                      hint: 'e.g., Senior Full-Stack & AI Engineer',
                                      controller: _headlineController,
                                    ),
                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppTextField(
                                            label: 'Current Company / Status',
                                            hint: 'e.g., Google / Open to Work',
                                            controller: _companyController,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: AppTextField(
                                            label: 'Location',
                                            hint: 'e.g., Bangalore, India (or Remote)',
                                            controller: _locationController,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppTextField(
                                            label: 'Years of Experience',
                                            hint: 'e.g., 5',
                                            keyboardType: TextInputType.number,
                                            controller: _expController,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: AppTextField(
                                            label: 'Target Salary (\$ / year)',
                                            hint: 'e.g., 140000',
                                            keyboardType: TextInputType.number,
                                            controller: _salaryController,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    AppTextField(
                                      label: 'Professional Summary / Bio',
                                      hint: 'Highlight your primary expertise, stack, and career accomplishments...',
                                      controller: _bioController,
                                      maxLines: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Technical Skills Card (Live Add / Remove)
                              AppCard(
                                padding: EdgeInsets.all(isDesktop ? 28 : 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.code, color: AppColors.accentCyan, size: 22),
                                        const SizedBox(width: 8),
                                        Text('Technical Skills & Stack', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                        const Spacer(),
                                        Text('${_skills.length} skills listed', style: AppTypography.bodySmall),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Add your verified languages, frameworks, and cloud platforms. These directly impact AI interview matching.',
                                      style: AppTypography.bodySmall,
                                    ),
                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppTextField(
                                            hint: 'Type a skill (e.g. Flutter, Python, Docker, AWS, GraphQL) & press Add',
                                            controller: _skillInputController,
                                            onSubmitted: (_) => _addSkill(),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        AppButton(
                                          label: 'Add Skill',
                                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                          onPressed: _addSkill,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    if (_skills.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Text('No skills added yet. Type a skill above to start building your technical profile.', style: AppTypography.bodySmall),
                                      )
                                    else
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: List.generate(_skills.length, (index) {
                                          final s = _skills[index];
                                          final name = s['name'] as String;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () => _removeSkill(index),
                                                  child: const Icon(Icons.close, size: 14, color: AppColors.textTertiary),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                  ],
                                ),
                              ),
                            ],
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

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentCyan),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}
