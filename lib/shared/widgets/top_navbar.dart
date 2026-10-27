import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import 'sidebar_navigation.dart';

class TopNavbar extends ConsumerWidget {
  const TopNavbar({super.key});

  void _showNotifications(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131522),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final notifsAsync = ref.watch(notificationsProvider);

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Notifications & Invites',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () async {
                          await ref.read(notificationRepoProvider).markAllAsRead();
                          ref.invalidate(notificationsProvider);
                        },
                        child: const Text('Mark all read', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFF222538), height: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: notifsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (e, _) => Center(child: Text('Error loading notifications: $e', style: const TextStyle(color: Colors.white70))),
                      data: (list) {
                        if (list.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 48, color: Colors.white.withOpacity(0.3)),
                                const SizedBox(height: 12),
                                const Text('No notifications yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final n = list[idx];
                            final isInvite = n.notificationType == 'INTERVIEW_INVITE';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: n.isRead ? const Color(0xFF181A2A) : const Color(0xFF1E2038),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isInvite
                                      ? const Color(0xFFD946EF).withOpacity(0.4)
                                      : (n.isRead ? const Color(0xFF2E324D) : AppColors.primary.withOpacity(0.4)),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isInvite ? Icons.videocam : Icons.info_outline,
                                        size: 18,
                                        color: isInvite ? const Color(0xFFD946EF) : AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      if (!n.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    n.message,
                                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                                  ),
                                  if (n.link.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            ref.read(notificationRepoProvider).markAsRead(n.id);
                                            ref.invalidate(notificationsProvider);
                                            context.go(n.link);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isInvite ? const Color(0xFFD946EF) : AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.login, size: 14),
                                          label: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openMobileMenu(BuildContext context, user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppMobileDrawer(
        user: user,
        currentRoute: GoRouterState.of(context).uri.path,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final notifsAsync = ref.watch(notificationsProvider);

    final unreadCount = notifsAsync.value?.where((n) => !n.isRead).length ?? 0;

    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 14),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.95),
        border: const Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Mobile Hamburger Menu (Available on all mobile screens)
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 24),
              tooltip: 'Navigation Menu',
              onPressed: () => _openMobileMenu(context, user),
            ),
            const SizedBox(width: 4),
          ],

          // Brand Logo: "nxus"
          InkWell(
            onTap: () => context.go('/'),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTypography.displaySmall.copyWith(
                      fontSize: isDesktop ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                    children: [
                      const TextSpan(text: 'nxsu'),
                      TextSpan(
                        text: 's',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.top,
                        child: Transform.translate(
                          offset: const Offset(2, -4),
                          child: Text(
                            'x',
                            style: TextStyle(
                              fontSize: isDesktop ? 12 : 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isDesktop) ...[
            const SizedBox(width: 32),
            _NavLink(title: 'Browse Jobs', onTap: () => context.go('/jobs')),
            const SizedBox(width: 20),
            _NavLink(title: 'Live AI Demo', onTap: () => context.go('/live-interview')),
            if (user != null) ...[
              const SizedBox(width: 20),
              _NavLink(title: 'Messages', onTap: () => context.go('/messages')),
            ],
          ],

          const Spacer(),

          // Auth / User actions
          if (user != null) ...[
            // Notification Bell Icon with Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                  tooltip: 'Invitations & Notifications',
                  onPressed: () => _showNotifications(context, ref),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),

            // User Avatar & Role (Desktop)
            if (isDesktop) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user.fullName,
                      style: AppTypography.labelLarge.copyWith(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.role,
                        style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Portal Navigation Button
            ElevatedButton(
              onPressed: () {
                if (user.isCandidate) {
                  context.go('/candidate/dashboard');
                } else if (user.isRecruiter) {
                  context.go('/recruiter/dashboard');
                } else {
                  context.go('/admin/dashboard');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12, vertical: 8),
              ),
              child: Text(
                isDesktop ? 'Dashboard' : 'Portal',
                style: TextStyle(fontSize: isDesktop ? 13 : 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),

            if (isDesktop)
              IconButton(
                icon: const Icon(Icons.logout, size: 20, color: AppColors.textSecondary),
                tooltip: 'Sign Out',
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/');
                },
              ),
          ] else ...[
            // Sign In Button
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => context.go('/login'),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 18 : 12, vertical: 8),
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: isDesktop ? 13 : 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Start Free Trial
            if (isDesktop)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => context.go('/register'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Register',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NavLink({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
