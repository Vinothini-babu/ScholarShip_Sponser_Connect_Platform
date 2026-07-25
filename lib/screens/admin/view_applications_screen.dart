import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ViewApplicationsScreen extends StatelessWidget {
  const ViewApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "View Applications",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "Student Applications",
            style: AppTextStyles.title.copyWith(fontSize: 22, color: AppColors.textPrimary),
          ),

          const SizedBox(height: 6),

          Text(
            "Review all scholarship applications.",
            style: AppTextStyles.subtitle,
          ),

          const SizedBox(height: 22),

          _buildApplicationCard(
            context,
            student: "Vinothini",
            scholarship: "Government Scholarship",
            sponsor: "ABC Foundation",
            status: "Pending",
          ),

          const SizedBox(height: 16),

          _buildApplicationCard(
            context,
            student: "Rahul",
            scholarship: "Merit Scholarship",
            sponsor: "Bright Future Trust",
            status: "Approved",
          ),

          const SizedBox(height: 16),

          _buildApplicationCard(
            context,
            student: "Priya",
            scholarship: "Sports Scholarship",
            sponsor: "Helping Hands",
            status: "Rejected",
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(
      BuildContext context, {
        required String student,
        required String scholarship,
        required String sponsor,
        required String status,
      }) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case "Approved":
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case "Rejected":
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    student.isNotEmpty ? student[0].toUpperCase() : "?",
                    style: AppTextStyles.title.copyWith(color: AppColors.primary, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  student,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: AppTextStyles.subtitle.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Icon(Icons.school_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  scholarship,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Icon(Icons.business_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  sponsor,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Viewing $student Application 👀")),
                    );
                  },
                  icon: Icon(Icons.visibility_rounded, size: 17, color: AppColors.primary),
                  label: Text("View", style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("$student Application Removed 🗑️")),
                    );
                  },
                  icon: const Icon(Icons.delete_rounded, size: 17),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
