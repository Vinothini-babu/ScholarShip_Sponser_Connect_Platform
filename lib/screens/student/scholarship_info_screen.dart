import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../utils/eligibility_utils.dart';

/// Shows full details of a single scholarship — used when the student
/// taps a scholarship they are NOT eligible for, so instead of dumping
/// them into the (empty-for-them) Eligible Scholarships list, they see
/// what the scholarship is about and why they don't currently qualify.
class ScholarshipInfoScreen extends StatelessWidget {
  final String scholarshipId;

  const ScholarshipInfoScreen({super.key, required this.scholarshipId});

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return "${date.day}/${date.month}/${date.year}";
    }
    return value?.toString() ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          "Scholarship Details",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('scholarships')
            .doc(scholarshipId)
            .snapshots(),
        builder: (context, scholarshipSnapshot) {
          if (scholarshipSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!scholarshipSnapshot.hasData ||
              !scholarshipSnapshot.data!.exists) {
            return Center(
              child: Text(
                "Scholarship not found",
                style: AppTextStyles.subtitle,
              ),
            );
          }

          final scholarship = scholarshipSnapshot.data!.data() ?? {};

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: user == null
                ? null
                : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, studentSnapshot) {
              final studentData = studentSnapshot.data?.data() ?? {};

              final result = checkScholarshipEligibility(
                scholarship,
                studentData,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: .75),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.school, color: Colors.white, size: 30),
                          const SizedBox(height: 12),
                          Text(
                            scholarship["title"]?.toString() ?? "Scholarship",
                            style: AppTextStyles.title.copyWith(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "By ${scholarship["sponsorName"]?.toString() ?? "Sponsor"}",
                            style: AppTextStyles.subtitle.copyWith(
                              color: Colors.white.withValues(alpha: .9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.currency_rupee,
                            label: "Amount",
                            value: scholarship["amount"]?.toString() ?? "-",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.calendar_today,
                            label: "Deadline",
                            value: _formatDate(scholarship["lastDate"]),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    if ((scholarship["description"]?.toString() ?? "")
                        .isNotEmpty) ...[
                      Text("About this scholarship", style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      )),
                      const SizedBox(height: 8),
                      Text(
                        scholarship["description"].toString(),
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    Text("Eligibility criteria", style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    )),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        (scholarship["eligibility"]?.toString().isNotEmpty ?? false)
                            ? scholarship["eligibility"].toString()
                            : "See course, category, percentage and income requirements set by the sponsor.",
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: .25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 18, color: AppColors.error),
                              const SizedBox(width: 8),
                              Text(
                                "You're not eligible for this scholarship",
                                style: AppTextStyles.subtitle.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (result.reasons.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...result.reasons.map(
                                  (reason) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  "• $reason",
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(value, style: AppTextStyles.subtitle.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}