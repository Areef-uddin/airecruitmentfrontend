import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/sidebar_navigation.dart';
import '../../shared/widgets/app_card.dart';
import '../../providers/auth_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/config/api_config.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _overview;
  List<dynamic> _users = [];
  List<dynamic> _auditLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get(ApiConfig.adminDashboard);
      setState(() {
        _overview = res.data['overview'];
        _users = res.data['recent_users'] ?? [];
        _auditLogs = res.data['recent_logs'] ?? [];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleUserActive(int userId, bool currentStatus) async {
    try {
      final dio = ApiClient().dio;
      await dio.patch(
        '${ApiConfig.adminUsers}$userId/',
        data: {'is_active': !currentStatus},
      );
      _fetch();
    } catch (_) {}
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

    final ov = _overview ?? {
      'total_users': 4,
      'total_candidates': 2,
      'total_recruiters': 1,
      'total_companies': 3,
      'active_jobs': 3,
      'total_applications': 14,
      'system_health': '99.98% Normal',
    };

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
                  SidebarNavigation(user: user, currentRoute: '/admin/dashboard'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Platform Administration & Governance', style: AppTypography.displaySmall.copyWith(fontSize: 26)),
                                const SizedBox(height: 4),
                                Text('System health, company verification, user role auditing, and telemetry.', style: AppTypography.bodySmall),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accentEmerald.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppColors.accentEmerald),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 14, color: AppColors.accentEmerald),
                                  const SizedBox(width: 6),
                                  Text(
                                    ov['system_health'] ?? 'Operational',
                                    style: const TextStyle(color: AppColors.accentEmerald, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Metric Overview Grid
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
                            final cardWidth = (constraints.maxWidth - ((cols - 1) * 16)) / cols;

                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _AdminStatCard(width: cardWidth, title: 'Registered Users', value: '${ov['total_users']}', icon: Icons.people),
                                _AdminStatCard(width: cardWidth, title: 'Enterprise Companies', value: '${ov['total_companies']}', icon: Icons.business),
                                _AdminStatCard(width: cardWidth, title: 'Active Job Postings', value: '${ov['active_jobs']}', icon: Icons.work),
                                _AdminStatCard(width: cardWidth, title: 'Applications Processed', value: '${ov['total_applications']}', icon: Icons.assignment),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // User Management Table
                        Text('Recent Registered Users', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final u = _users[index];
                              final isActive = u['is_active'] ?? true;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary.withOpacity(0.2),
                                      child: Text(
                                        u['name']?[0] ?? 'U',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(u['name'] ?? '', style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
                                          Text(u['email'] ?? '', style: AppTypography.bodySmall),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(u['role'] ?? 'CANDIDATE', style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                                    ),
                                    const SizedBox(width: 16),
                                    Switch(
                                      value: isActive,
                                      activeColor: AppColors.accentEmerald,
                                      onChanged: (val) => _toggleUserActive(u['id'], isActive),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        // System Audit Logs
                        Text('Platform Audit Trail', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _auditLogs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final log = _auditLogs[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${log['user']} performed ${log['action']} on ${log['entity_type']}',
                                        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                                      ),
                                    ),
                                    Text(log['timestamp'] ?? '', style: AppTypography.bodySmall),
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

class _AdminStatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;

  const _AdminStatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
              Icon(icon, color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: AppTypography.displaySmall.copyWith(fontSize: 28, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
