import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/application_model.dart';
import '../../../services/application_service.dart';
import 'application_details_screen.dart';

class SponsorApplicationsScreen extends StatelessWidget {
  SponsorApplicationsScreen({super.key});

  final ApplicationService _applicationService =
  ApplicationService();

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
          "Applications Received",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      body: StreamBuilder<List<ApplicationModel>>(
        stream: _applicationService
            .getSponsorApplications(sponsorId),

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
                  "Unable to load applications.\n\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle,
                ),
              ),
            );
          }

          final applications =
              snapshot.data ?? [];

          if (applications.isEmpty) {
            return _emptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: applications.length,

            itemBuilder: (context, index) {
              final application =
              applications[index];

              return Padding(
                padding:
                const EdgeInsets.only(bottom: 16),

                child: _ApplicationCard(
                  application: application,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Icon(
              Icons.assignment_outlined,
              size: 70,
              color: AppColors.secondary,
            ),

            const SizedBox(height: 16),

            Text(
              "No Applications Yet",
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(
                fontSize: 19,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Student applications for your scholarships will appear here.",
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
// APPLICATION CARD
// =========================================================

class _ApplicationCard extends StatelessWidget {
  final ApplicationModel application;

  const _ApplicationCard({
    required this.application,
  });

  Color _statusColor() {
    switch (application.status) {
      case "Approved":
        return AppColors.success;

      case "Rejected":
        return AppColors.error;

      default:
        return AppColors.warning;
    }
  }

  IconData _statusIcon() {
    switch (application.status) {
      case "Approved":
        return Icons.check_circle_rounded;

      case "Rejected":
        return Icons.cancel_rounded;

      default:
        return Icons.hourglass_top_rounded;
    }
  }

  String _formatDate() {
    final date =
    application.appliedAt.toDate();

    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  @override
  Widget build(BuildContext context) {

    final statusColor =
    _statusColor();

    return Container(
      width: double.infinity,
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
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          // -------------------------------------------------
          // STUDENT + STATUS
          // -------------------------------------------------

          Row(
            children: [

              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(14),
                ),

                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  application.studentName.isEmpty
                      ? "Student"
                      : application.studentName,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),

                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
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
                  statusColor.withOpacity(0.12),
                  borderRadius:
                  BorderRadius.circular(20),
                ),

                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [

                    Icon(
                      _statusIcon(),
                      size: 13,
                      color: statusColor,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      application.status,

                      style:
                      AppTextStyles.subtitle.copyWith(
                        color: statusColor,
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Divider(
            color: AppColors.textSecondary
                .withOpacity(0.12),
          ),

          const SizedBox(height: 14),

          // -------------------------------------------------
          // SCHOLARSHIP
          // -------------------------------------------------

          Row(
            children: [

              Icon(
                Icons.workspace_premium_rounded,
                size: 18,
                color: AppColors.secondary,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  application.scholarshipTitle,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight:
                    FontWeight.w600,
                    fontSize: 14,
                  ),

                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------
          // AMOUNT
          // -------------------------------------------------

          Row(
            children: [

              Icon(
                Icons.currency_rupee_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 5),

              Text(
                "Amount: ${application.amount}",

                style:
                AppTextStyles.subtitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight:
                  FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // -------------------------------------------------
          // COLLEGE
          // -------------------------------------------------

          Row(
            children: [

              Icon(
                Icons.account_balance_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 5),

              Expanded(
                child: Text(
                  application.studentCollege.isEmpty
                      ? "College not available"
                      : application.studentCollege,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                  ),

                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // -------------------------------------------------
          // APPLIED DATE
          // -------------------------------------------------

          Row(
            children: [

              Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 5),

              Text(
                "Applied: ${_formatDate()}",

                style:
                AppTextStyles.subtitle.copyWith(
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // -------------------------------------------------
          // VIEW APPLICATION
          // -------------------------------------------------

          SizedBox(
            width: double.infinity,

            child: OutlinedButton(
              onPressed: () {
                // Details screen will be connected
                // in the next step.
              },

              style:
              OutlinedButton.styleFrom(
                foregroundColor:
                AppColors.primary,

                side: BorderSide(
                  color: AppColors.primary,
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

              child: const Text(
                "View Application",
                style: TextStyle(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}