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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && mounted) {
        if (user.isCandidate) {
          context.go('/candidate/dashboard');
        } else if (user.isRecruiter) {
          context.go('/recruiter/dashboard');
        } else {
          context.go('/admin/dashboard');
        }
      }
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (success && mounted) {
      final user = ref.read(authProvider).user;
      if (user?.isCandidate ?? false) {
        context.go('/candidate/dashboard');
      } else if (user?.isRecruiter ?? false) {
        context.go('/recruiter/dashboard');
      } else {
        context.go('/admin/dashboard');
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
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AppCard(
                    padding: const EdgeInsets.all(36),
                    hasGlow: true,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome Back',
                            style: AppTypography.displaySmall.copyWith(fontSize: 28),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to access your recruitment portal & AI sessions',
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Quick Demo Account Selectors


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

                          AppTextField(
                            label: 'Email Address',
                            hint: 'name@company.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.textTertiary),
                            validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 18),

                          AppTextField(
                            label: 'Password',
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: true,
                            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textTertiary),
                            validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                          ),
                          const SizedBox(height: 28),

                          AppButton(
                            label: 'Sign In',
                            isLoading: authState.isLoading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have an account? ", style: AppTypography.bodySmall),
                              InkWell(
                                onTap: () => context.go('/register'),
                                child: Text(
                                  'Create Account',
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
