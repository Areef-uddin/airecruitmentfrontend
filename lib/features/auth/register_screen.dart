import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_card.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyController = TextEditingController();
  String _selectedRole = 'CANDIDATE';
  final _formKey = GlobalKey<FormState>();

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
      email: _emailController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      role: _selectedRole,
      companyName: _selectedRole == 'RECRUITER' ? _companyController.text.trim() : null,
    );

    if (success && mounted) {
      if (_selectedRole == 'CANDIDATE') {
        context.go('/candidate/dashboard');
      } else {
        context.go('/recruiter/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopNavbar(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: AppCard(
                    padding: const EdgeInsets.all(36),
                    hasGlow: true,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Create Your Account',
                            style: AppTypography.displaySmall.copyWith(fontSize: 26),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join next-generation recruitment powered by explainable AI',
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Role Selector
                          Row(
                            children: [
                              Expanded(
                                child: _RoleCard(
                                  title: 'Job Seeker',
                                  subtitle: 'Find jobs & AI matching',
                                  icon: Icons.person_outline,
                                  isSelected: _selectedRole == 'CANDIDATE',
                                  onTap: () => setState(() => _selectedRole = 'CANDIDATE'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _RoleCard(
                                  title: 'Recruiter / Employer',
                                  subtitle: 'Post jobs & screen candidates',
                                  icon: Icons.business_center_outlined,
                                  isSelected: _selectedRole == 'RECRUITER',
                                  onTap: () => setState(() => _selectedRole = 'RECRUITER'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          if (authState.error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.accentRose.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.accentRose),
                              ),
                              child: Text(
                                authState.error!,
                                style: const TextStyle(color: AppColors.accentRose, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'First Name',
                                  hint: 'Amira',
                                  controller: _firstNameController,
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: AppTextField(
                                  label: 'Last Name',
                                  hint: 'Patel',
                                  controller: _lastNameController,
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          AppTextField(
                            label: 'Email',
                            hint: 'amira@example.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 16),

                          AppTextField(
                            label: 'Username',
                            hint: 'amira_tech',
                            controller: _usernameController,
                            validator: (v) => v == null || v.length < 3 ? 'Min 3 chars' : null,
                          ),
                          const SizedBox(height: 16),

                          if (_selectedRole == 'RECRUITER') ...[
                            AppTextField(
                              label: 'Company Name',
                              hint: 'NexusAI Technologies',
                              controller: _companyController,
                              validator: (v) => v == null || v.isEmpty ? 'Company name required' : null,
                            ),
                            const SizedBox(height: 16),
                          ],

                          AppTextField(
                            label: 'Password',
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: true,
                            validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                          ),
                          const SizedBox(height: 28),

                          AppButton(
                            label: 'Create Account',
                            isLoading: authState.isLoading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account? ', style: AppTypography.bodySmall),
                              InkWell(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  'Sign In',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 24),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
