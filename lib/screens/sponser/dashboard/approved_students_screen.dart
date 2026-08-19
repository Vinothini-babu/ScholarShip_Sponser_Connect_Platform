import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/application_model.dart';

import '../applications/application_details_screen.dart';

class ApprovedStudentsScreen extends StatelessWidget {
  ApprovedStudentsScreen({super.key});

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final sponsorId =
        FirebaseAuth.instance.currentUser?.uid;

    if (sponsorId == null) {
      return const Scaffold(
        body: Center(
          child: Text("Please login again"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,

        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),

        title: Text(
          "Approved Students",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("applications")
            .where(
          "sponsorId",
          isEqualTo: sponsorId,
        )
            .where(
          "status",
          isEqualTo: "Approved",
        )
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  "Unable to load approved students.\n\n"
                      "${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _emptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,

            itemBuilder: (context, index) {

              final doc = docs[index];

              final application =
              ApplicationModel.fromMap(
                doc.data()
                as Map<String, dynamic>,
                doc.id,
              );

              return Padding(
                padding:
                const EdgeInsets.only(bottom: 16),

                child: _ApprovedStudentCard(
                  application: application,
                ),
              );
            },
          );
        },
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(
              Icons.people_outline_rounded,
              size: 70,
              color: AppColors.secondary,
            ),

            const SizedBox(height: 16),

            Text(
              "No Approved Students",
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(
                fontSize: 19,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Students whose applications are approved "
                  "will appear here.",
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle,
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// APPROVED STUDENT CARD
// =========================================================

class _ApprovedStudentCard
    extends StatelessWidget {

  final ApplicationModel application;

  const _ApprovedStudentCard({
    required this.application,
  });

  String _formatDate() {
    final date =
    application.appliedAt.toDate();

    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius:
        BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          // =================================================
          // STUDENT HEADER
          // =================================================

          Row(
            children: [

              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color:
                  AppColors.success
                      .withOpacity(0.12),

                  borderRadius:
                  BorderRadius.circular(14),
                ),

                child: Icon(
                  Icons.person_rounded,
                  color:
                  AppColors.success,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  application.studentName.isEmpty
                      ? "Student"
                      : application.studentName,

                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    AppColors.textPrimary,
                  ),
                ),
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color:
                  AppColors.success
                      .withOpacity(0.12),

                  borderRadius:
                  BorderRadius.circular(20),
                ),

                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [

                    Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color:
                      AppColors.success,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      "Approved",
                      style:
                      AppTextStyles.subtitle
                          .copyWith(
                        fontSize: 11,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Divider(
            color:
            AppColors.textSecondary
                .withOpacity(0.12),
          ),

          const SizedBox(height: 14),

          // =================================================
          // COLLEGE
          // =================================================

          Row(
            children: [

              Icon(
                Icons.account_balance_rounded,
                size: 17,
                color:
                AppColors.textSecondary,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  application.studentCollege.isEmpty
                      ? "College not available"
                      : application.studentCollege,

                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    color:
                    AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // =================================================
          // SCHOLARSHIP
          // =================================================

          Row(
            children: [

              Icon(
                Icons.workspace_premium_rounded,
                size: 17,
                color:
                AppColors.secondary,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  application.scholarshipTitle,

                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // =================================================
          // AMOUNT + DATE
          // =================================================

          Row(
            children: [

              Icon(
                Icons.currency_rupee_rounded,
                size: 16,
                color:
                AppColors.textSecondary,
              ),

              const SizedBox(width: 5),

              Text(
                application.amount,
                style:
                AppTextStyles.subtitle.copyWith(
                  fontSize: 13,
                  fontWeight:
                  FontWeight.w600,
                  color:
                  AppColors.textPrimary,
                ),
              ),

              const Spacer(),

              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color:
                AppColors.textSecondary,
              ),

              const SizedBox(width: 5),

              Text(
                _formatDate(),
                style:
                AppTextStyles.subtitle.copyWith(
                  fontSize: 12,
                  color:
                  AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // =================================================
          // VIEW APPLICATION
          // =================================================

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              onPressed: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ApplicationDetailsScreen(
                          application:
                          application,
                        ),
                  ),
                );

              },

              icon: const Icon(
                Icons.visibility_rounded,
                size: 18,
              ),

              label: const Text(
                "View Application",
              ),

              style:
              OutlinedButton.styleFrom(
                foregroundColor:
                AppColors.primary,

                side: BorderSide(
                  color:
                  AppColors.primary,
                  width: 1.3,
                ),

                padding:
                const EdgeInsets.symmetric(
                  vertical: 13,
                ),

                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}