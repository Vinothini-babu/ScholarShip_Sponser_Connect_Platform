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
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Scholarship Details",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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

              return TweenAnimationBuilder<double>(
                key: ValueKey(scholarshipId),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 20),
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: .78),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .28),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              scholarship["title"]?.toString() ?? "Scholarship",
                              style: AppTextStyles.title.copyWith(
                                color: Colors.white,
                                fontSize: 20,
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

                      const SizedBox(height: 20),

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

                      const SizedBox(height: 22),

                      if ((scholarship["description"]?.toString() ?? "")
                          .isNotEmpty) ...[
                        _SectionLabel(icon: Icons.info_outline_rounded, text: "About this scholarship"),
                        const SizedBox(height: 10),
                        Text(
                          scholarship["description"].toString(),
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],

                      _SectionLabel(icon: Icons.checklist_rounded, text: "Eligibility criteria"),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.warning.withValues(alpha: .2)),
                        ),
                        child: Text(
                          (scholarship["eligibility"]?.toString().isNotEmpty ?? false)
                              ? scholarship["eligibility"].toString()
                              : "See course, category, percentage and income requirements set by the sponsor.",
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: .25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: .15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "You're not eligible for this scholarship",
                                    style: AppTextStyles.subtitle.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (result.reasons.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              ...result.reasons.map(
                                    (reason) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Icon(Icons.circle, size: 5, color: AppColors.error),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: AppTextStyles.subtitle.copyWith(
                                            fontSize: 12.5,
                                            color: AppColors.textPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.subtitle.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(value, style: AppTextStyles.subtitle.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}