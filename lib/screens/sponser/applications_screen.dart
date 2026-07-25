import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Applications Received",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("applications")
            .orderBy("appliedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text("No Applications Found", style: AppTextStyles.subtitle),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                "Student Applications",
                style: AppTextStyles.title.copyWith(fontSize: 22, color: AppColors.textPrimary),
              ),

              const SizedBox(height: 6),

              Text(
                "Review applications submitted by students.",
                style: AppTextStyles.subtitle,
              ),

              const SizedBox(height: 22),

              _buildApplicationCard(
                context,
                studentName: "Vinothini",
                college: "P.K.R Arts College",
                course: "B.Sc Computer Science",
                scholarship: "Government Scholarship",
              ),

              const SizedBox(height: 16),

              _buildApplicationCard(
                context,
                studentName: "Rahul",
                college: "ABC Engineering College",
                course: "B.E Computer Science",
                scholarship: "Merit Scholarship",
              ),

              const SizedBox(height: 16),

              _buildApplicationCard(
                context,
                studentName: "Priya",
                college: "XYZ College",
                course: "BCA",
                scholarship: "Sports Scholarship",
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard(
      BuildContext context, {
        required String studentName,
        required String college,
        required String course,
        required String scholarship,
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
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : "?",
                    style: AppTextStyles.title.copyWith(color: AppColors.primary, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  studentName,
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

          _detailRow(Icons.school_rounded, "College", college),
          const SizedBox(height: 6),
          _detailRow(Icons.menu_book_rounded, "Course", course),
          const SizedBox(height: 6),
          _detailRow(Icons.workspace_premium_rounded, "Scholarship", scholarship),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("$studentName Approved Successfully ✅")),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text("Approve"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("$studentName Rejected ❌")),
                    );
                  },
                  icon: Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                  label: Text("Reject", style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.error, width: 1.4),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: AppTextStyles.subtitle.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
