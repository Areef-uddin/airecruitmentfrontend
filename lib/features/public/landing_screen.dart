import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/app_button.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user != null) {
      // While redirecting or if already logged in, show clean loader or redirect immediately
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopNavbar(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // HERO SECTION (Directly inspired by reference image)
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.4),
                        radius: 1.2,
                        colors: [
                          Color(0x33D946EF), // Soft magenta ambient glow
                          Color(0x118B5CF6),
                          AppColors.background,
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 64 : 20,
                      vertical: isDesktop ? 64 : 40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 950),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Badge pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Introducing TalentAI 2.0 Autonomous Recruiter',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Main Headline
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: AppTypography.displayLarge.copyWith(
                                  fontSize: isDesktop ? 54 : 34,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                  color: Colors.white,
                                ),
                                children: [
                                  const TextSpan(text: 'Transform Your Workforce With\nan '),
                                  WidgetSpan(
                                    child: ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [Color(0xFFEC4899), Color(0xFFD946EF), Color(0xFF8B5CF6)],
                                      ).createShader(bounds),
                                      child: Text(
                                        'AI-First Platform',
                                        style: AppTypography.displayLarge.copyWith(
                                          fontSize: isDesktop ? 54 : 34,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' Built for\nModern HR'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Subtitle
                            Text(
                              'From intelligent screening to real-time analytics, TalentAI automates what slows you down and amplifies what drives success.',
                              style: AppTypography.bodyLarge.copyWith(
                                fontSize: isDesktop ? 18 : 15,
                                color: const Color(0xFF94A3B8),
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 36),

                            // Call to Action Buttons
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.25),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(100),
                                      onTap: () => context.go('/live-interview'),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text(
                                              'Get Started',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_outward, color: Colors.black, size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                AppButton(
                                  label: 'Explore Open Jobs',
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () => context.go('/jobs'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 52),

                            // LIVE INTERVIEW SHOWCASE BANNER
                            GestureDetector(
                              onTap: () => context.go('/live-interview'),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.15),
                                      blurRadius: 30,
                                      offset: const Offset(0, 8),
                                    )
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.videocam, color: AppColors.primary, size: 28),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Experience Live WebRTC Video Interview & AI Evaluation',
                                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Live camera video, real-time live captions, instant multilingual translation & AI scoring.',
                                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: const Text(
                                        'Launch Demo ↗',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // THREE PILLARS / ADVANTAGES
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 20, vertical: 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1150),
                        child: Column(
                          children: [
                            Text(
                              'Designed for Modern Engineering & HR Workflows',
                              style: AppTypography.displaySmall.copyWith(fontSize: isDesktop ? 30 : 22),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 36),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final cols = constraints.maxWidth > 800 ? 3 : 1;
                                return Wrap(
                                  spacing: 20,
                                  runSpacing: 20,
                                  children: [
                                    _FeatureCard(
                                      width: cols == 3 ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                                      icon: Icons.psychology_outlined,
                                      accentColor: AppColors.primary,
                                      title: 'Explainable AI Matching',
                                      description: 'Zero black-box hiring decisions. Understand exactly which skills match and where qualifications require verification.',
                                    ),
                                    _FeatureCard(
                                      width: cols == 3 ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                                      icon: Icons.videocam_outlined,
                                      accentColor: AppColors.secondary,
                                      title: 'Autonomous Technical Screening',
                                      description: 'Interactive AI agents conduct real-time audio/video screenings, dynamically adapting questions to candidate seniority.',
                                    ),
                                    _FeatureCard(
                                      width: cols == 3 ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                                      icon: Icons.speed_outlined,
                                      accentColor: AppColors.accentCyan,
                                      title: '70% Faster Time-to-Offer',
                                      description: 'Eliminate tedious manual resume screening, automate interview scheduling, and keep candidate pipelines flowing smoothly.',
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // FOOTER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Center(
                      child: Text(
                        '© 2026 TalentAI Platform (Nxsus). All rights reserved. Built with Flutter Web & Android + Django REST Framework.',
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;

  const _FeatureCard({
    required this.width,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(height: 20),
          Text(title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
