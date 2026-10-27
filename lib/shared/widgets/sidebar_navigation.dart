import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/user_model.dart';

class SidebarItem {
  final String title;
  final IconData icon;
  final String route;

  const SidebarItem({required this.title, required this.icon, required this.route});
}

List<SidebarItem> getSidebarItems(UserModel? user) {
  if (user?.isCandidate ?? false) {
    return const [
      SidebarItem(title: 'Overview', icon: Icons.dashboard_outlined, route: '/candidate/dashboard'),
      SidebarItem(title: 'Direct Chat & Messages', icon: Icons.chat_bubble_outline, route: '/messages'),
      SidebarItem(title: 'Live AI Interview', icon: Icons.videocam_outlined, route: '/live-interview'),
      SidebarItem(title: 'My Applications', icon: Icons.assignment_outlined, route: '/candidate/applications'),
      SidebarItem(title: 'My Resumes', icon: Icons.description_outlined, route: '/candidate/resumes'),
      SidebarItem(title: 'Profile & Skills', icon: Icons.person_outline, route: '/candidate/profile'),
      SidebarItem(title: 'Explore Jobs', icon: Icons.search_outlined, route: '/jobs'),
    ];
  } else if (user?.isRecruiter ?? false) {
    return const [
      SidebarItem(title: 'Overview', icon: Icons.analytics_outlined, route: '/recruiter/dashboard'),
      SidebarItem(title: 'Candidate Messages', icon: Icons.chat_bubble_outline, route: '/messages'),
      SidebarItem(title: 'Applicant Pipeline', icon: Icons.view_kanban_outlined, route: '/recruiter/pipeline'),
      SidebarItem(title: 'Candidate Search', icon: Icons.people_outline, route: '/recruiter/candidates'),
      SidebarItem(title: 'Post New Job (AI)', icon: Icons.add_circle_outline, route: '/recruiter/create-job'),
      SidebarItem(title: 'Live AI Screening', icon: Icons.smart_toy_outlined, route: '/live-interview'),
      SidebarItem(title: 'Job Postings', icon: Icons.work_outline, route: '/recruiter/jobs'),
    ];
  } else if (user?.isSuperAdmin ?? false) {
    return const [
      SidebarItem(title: 'Platform Overview', icon: Icons.admin_panel_settings_outlined, route: '/admin/dashboard'),
      SidebarItem(title: 'Direct Chat & Messages', icon: Icons.chat_bubble_outline, route: '/messages'),
      SidebarItem(title: 'User Management', icon: Icons.manage_accounts_outlined, route: '/admin/dashboard'),
      SidebarItem(title: 'Live AI Screening', icon: Icons.videocam_outlined, route: '/live-interview'),
      SidebarItem(title: 'Browse Public Jobs', icon: Icons.explore_outlined, route: '/jobs'),
    ];
  } else {
    // Guest items for mobile drawer
    return const [
      SidebarItem(title: 'Browse Jobs', icon: Icons.work_outline, route: '/jobs'),
      SidebarItem(title: 'Live AI Interview Demo', icon: Icons.videocam_outlined, route: '/live-interview'),
      SidebarItem(title: 'Sign In', icon: Icons.login, route: '/login'),
      SidebarItem(title: 'Create Account', icon: Icons.person_add_outlined, route: '/register'),
    ];
  }
}

class SidebarNavigation extends StatelessWidget {
  final UserModel? user;
  final String currentRoute;

  const SidebarNavigation({
    super.key,
    required this.user,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final items = getSidebarItems(user);

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              user?.role == 'RECRUITER'
                  ? 'RECRUITER PORTAL'
                  : user?.role == 'SUPER_ADMIN'
                      ? 'ADMIN PORTAL'
                      : 'CANDIDATE PORTAL',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = currentRoute.startsWith(item.route) && item.route != '/';

                return InkWell(
                  onTap: () {
                    context.go(item.route);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 19,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          item.title,
                          style: AppTypography.labelLarge.copyWith(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AppMobileDrawer extends StatelessWidget {
  final UserModel? user;
  final String currentRoute;

  const AppMobileDrawer({
    super.key,
    required this.user,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final items = getSidebarItems(user);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1019),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF2E324D), width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle Indicator
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // User Info or Guest Welcome
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user?.fullName.isNotEmpty ?? false ? user!.fullName[0].toUpperCase() : (user != null ? 'U' : 'T'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'TalentAI Platform',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          user?.role == 'RECRUITER'
                              ? 'Recruiter Portal'
                              : user?.role == 'SUPER_ADMIN'
                                  ? 'Platform Admin'
                                  : (user != null ? 'Candidate Portal' : 'Welcome to TalentAI'),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF222538), height: 1),
            const SizedBox(height: 8),

            // Navigation Links
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = currentRoute.startsWith(item.route) && item.route != '/';

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      context.go(item.route);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected ? Border.all(color: AppColors.primary.withOpacity(0.4)) : null,
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                          const SizedBox(width: 14),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (user != null) ...[
              const Divider(color: Color(0xFF222538), height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.accentRose),
                title: const Text('Sign Out', style: TextStyle(color: AppColors.accentRose, fontSize: 13, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
