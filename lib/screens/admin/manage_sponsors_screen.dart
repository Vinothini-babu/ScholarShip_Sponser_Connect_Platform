import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ManageSponsorsScreen extends StatelessWidget {
  const ManageSponsorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Manage Sponsors",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "Registered Sponsors",
            style: AppTextStyles.title.copyWith(fontSize: 22, color: AppColors.textPrimary),
          ),

          const SizedBox(height: 6),

          Text(
            "View and manage all sponsors.",
            style: AppTextStyles.subtitle,
          ),

          const SizedBox(height: 22),

          _buildSponsorCard(
            context,
            sponsorName: "ABC Foundation",
            email: "abcfoundation@gmail.com",
            scholarships: "12",
          ),

          const SizedBox(height: 16),

          _buildSponsorCard(
            context,
            sponsorName: "Bright Future Trust",
            email: "brightfuture@gmail.com",
            scholarships: "8",
          ),

          const SizedBox(height: 16),

          _buildSponsorCard(
            context,
            sponsorName: "Helping Hands",
            email: "helpinghands@gmail.com",
            scholarships: "15",
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorCard(
      BuildContext context, {
        required String sponsorName,
        required String email,
        required String scholarships,
      }) {
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
                child: Icon(Icons.business_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  sponsorName,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Icon(Icons.email_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  email,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Icon(Icons.school_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                "$scholarships Scholarships",
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
                      SnackBar(content: Text("Viewing $sponsorName Profile 👤")),
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
                      SnackBar(content: Text("$sponsorName Removed Successfully 🗑️")),
                    );
                  },
                  icon: const Icon(Icons.delete_rounded, size: 17),
                  label: const Text("Remove"),
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
