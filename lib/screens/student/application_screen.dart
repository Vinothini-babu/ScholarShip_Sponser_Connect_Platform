import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/application_model.dart';
import '../../services/application_service.dart';

class ApplicationScreen extends StatelessWidget {
  ApplicationScreen({super.key});

  final ApplicationService _applicationService =
  ApplicationService();

  final String studentId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "My Applications",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
        body: StreamBuilder<List<ApplicationModel>>(
          stream: _applicationService.getStudentApplications(
            studentId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "No Applications Found",
                ),
              );
            }

            final applications = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final application = applications[index];

                Color statusColor;

                switch (application.status) {
                  case "Approved":
                    statusColor = AppColors.success;
                    break;

                  case "Rejected":
                    statusColor = AppColors.error;
                    break;

                  default:
                    statusColor = AppColors.warning;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ApplicationCard(
                    title: application.scholarshipTitle,
                    amount: application.amount,
                    status: application.status,
                    color: statusColor,
                  ),
                );
              },
            );
          },
        ),
    );
  }
}

class ApplicationCard extends StatelessWidget {
  final String title;
  final String amount;
  final String status;
  final Color color;

  ApplicationCard({
    super.key,
    required this.title,
    required this.amount,
    required this.status,
    required this.color,
  });

  IconData get _statusIcon {
    switch (status) {
      case "Approved":
        return Icons.check_circle_rounded;
      case "Rejected":
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.school_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, size: 13, color: color),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: AppTextStyles.subtitle.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.currency_rupee_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                "Scholarship Amount: $amount",
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary, width: 1.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "View Details",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
