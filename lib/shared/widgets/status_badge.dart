import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;

    switch (status.toUpperCase()) {
      case 'SUBMITTED':
        bg = AppColors.statusSubmitted.withOpacity(0.18);
        text = AppColors.statusSubmitted;
        label = 'Submitted';
        break;
      case 'SCREENING':
        bg = AppColors.statusScreening.withOpacity(0.18);
        text = AppColors.statusScreening;
        label = 'In Screening';
        break;
      case 'SHORTLISTED':
        bg = AppColors.statusShortlisted.withOpacity(0.18);
        text = AppColors.statusShortlisted;
        label = 'Shortlisted';
        break;
      case 'INTERVIEW_SCHEDULED':
      case 'INTERVIEW':
        bg = AppColors.statusInterview.withOpacity(0.18);
        text = AppColors.statusInterview;
        label = 'Interview';
        break;
      case 'OFFER':
        bg = AppColors.statusOffer.withOpacity(0.18);
        text = AppColors.statusOffer;
        label = 'Offer Extended';
        break;
      case 'REJECTED':
        bg = AppColors.statusRejected.withOpacity(0.18);
        text = AppColors.statusRejected;
        label = 'Declined';
        break;
      case 'ACTIVE':
        bg = AppColors.accentEmerald.withOpacity(0.18);
        text = AppColors.accentEmerald;
        label = 'Active';
        break;
      default:
        bg = AppColors.surfaceElevated;
        text = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: text.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
