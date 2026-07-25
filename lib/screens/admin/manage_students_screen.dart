import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ManageStudentsScreen extends StatelessWidget {
  const ManageStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Manage Students",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "Registered Students",
            style: AppTextStyles.title.copyWith(fontSize: 22, color: AppColors.textPrimary),
          ),

          const SizedBox(height: 6),

          Text(
            "View and manage all registered students.",
            style: AppTextStyles.subtitle,
          ),

          const SizedBox(height: 22),

          _buildStudentCard(
            context,
            name: "Vinothini",
            email: "vinothini@gmail.com",
            college: "P.K.R Arts College",
          ),

          const SizedBox(height: 16),

          _buildStudentCard(
            context,
            name: "Rahul",
            email: "rahul@gmail.com",
            college: "ABC Engineering College",
          ),

          const SizedBox(height: 16),

          _buildStudentCard(
            context,
            name: "Priya",
            email: "priya@gmail.com",
            college: "XYZ College",
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(
      BuildContext context, {
        required String name,
        required String email,
        required String college,
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
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: AppTextStyles.title.copyWith(color: AppColors.primary, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
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
              Expanded(
                child: Text(
                  college,
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
                      SnackBar(content: Text("Viewing $name Profile 👤")),
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
                      SnackBar(content: Text("$name Removed Successfully 🗑️")),
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
