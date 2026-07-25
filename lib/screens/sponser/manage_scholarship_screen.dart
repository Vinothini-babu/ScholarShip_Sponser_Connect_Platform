import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ManageScholarshipScreen extends StatelessWidget {
  const ManageScholarshipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Manage Scholarships",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "My Scholarships",
            style: AppTextStyles.title.copyWith(fontSize: 22, color: AppColors.textPrimary),
          ),

          const SizedBox(height: 6),

          Text(
            "Manage your published scholarships",
            style: AppTextStyles.subtitle,
          ),

          const SizedBox(height: 22),

          _buildScholarshipCard(
            context,
            title: "Government Scholarship",
            amount: "₹25,000",
            deadline: "30 Aug 2026",
            accent: AppColors.primary,
          ),

          const SizedBox(height: 16),

          _buildScholarshipCard(
            context,
            title: "Merit Scholarship",
            amount: "₹50,000",
            deadline: "15 Sep 2026",
            accent: AppColors.secondary,
          ),

          const SizedBox(height: 16),

          _buildScholarshipCard(
            context,
            title: "Sports Scholarship",
            amount: "₹30,000",
            deadline: "05 Oct 2026",
            accent: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildScholarshipCard(
      BuildContext context, {
        required String title,
        required String amount,
        required String deadline,
        required Color accent,
      }) {
    return Container(
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
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(Icons.currency_rupee_rounded, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      amount,
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      deadline,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 13),
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
                            const SnackBar(content: Text("Edit Feature Coming Soon ✏️")),
                          );
                        },
                        icon: Icon(Icons.edit_rounded, size: 17, color: AppColors.primary),
                        label: Text("Edit", style: TextStyle(color: AppColors.primary)),
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
                            const SnackBar(content: Text("Delete Feature Coming Soon 🗑️")),
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
          ),
        ],
      ),
    );
  }
}
