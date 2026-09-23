import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/status_timeline.dart'; // adjust path if your widgets folder differs
import 'upload_semester_update_screen.dart';

/// Shows the full details of a single submitted application.
/// Opened from MyApplicationsScreen's "View Details" button.
class ApplicationDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String applicationId;

  const ApplicationDetailsScreen({
    super.key,
    required this.data,
    required this.applicationId,
  });

  @override
  Widget build(BuildContext context) {
    final String status = data["status"]?.toString() ?? "Pending";

    Color statusColor;
    switch (status) {
      case "Approved":
        statusColor = AppColors.success;
        break;
      case "Rejected":
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.warning;
    }

    final List<StatusHistoryEntry> statusHistory =
    StatusHistoryEntry.listFromData(data);

    String appliedDate = "Date not available";
    DateTime? appliedAtDate;
    if (data["appliedAt"] is Timestamp) {
      final DateTime date = (data["appliedAt"] as Timestamp).toDate();
      appliedAtDate = date;
      appliedDate =
      "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          "Application Details",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
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
                    AppColors.primary.withOpacity(.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.school_rounded, color: Colors.white, size: 30),
                  const SizedBox(height: 12),
                  Text(
                    data["scholarshipTitle"]?.toString() ?? "Scholarship",
                    style: AppTextStyles.title.copyWith(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _DetailRow(
              icon: Icons.currency_rupee_rounded,
              label: "Amount",
              value: data["amount"]?.toString() ?? "Not available",
            ),
            _DetailRow(
              icon: Icons.account_balance_rounded,
              label: "College",
              value: data["studentCollege"]?.toString() ?? "Not available",
            ),
            _DetailRow(
              icon: Icons.email_outlined,
              label: "Email",
              value: data["studentEmail"]?.toString() ?? "Not available",
            ),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: "Applied On",
              value: appliedDate,
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    status == "Approved"
                        ? Icons.check_circle
                        : status == "Rejected"
                        ? Icons.cancel
                        : Icons.access_time_rounded,
                    color: statusColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Status: $status",
                    style: AppTextStyles.subtitle.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            StatusTimeline(
              history: statusHistory,
              currentStatus: status,
              appliedAt: appliedAtDate,
            ),

            // Semester renewal — only relevant once the application itself
            // is approved. Shows the student's current semester and a
            // button into UploadSemesterUpdateScreen (which itself handles
            // showing history / pending-review / suspended states).
            if (status == "Approved") ...[
              const SizedBox(height: 20),
              _SemesterUpdateCard(
                applicationId: applicationId,
                currentSemester: (data["currentSemester"] is int) ? data["currentSemester"] as int : 1,
              ),
            ],

            const SizedBox(height: 12),

            Text(
              "Application ID: $applicationId",
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterUpdateCard extends StatelessWidget {
  final String applicationId;
  final int currentSemester;

  const _SemesterUpdateCard({
    required this.applicationId,
    required this.currentSemester,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Semester $currentSemester",
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Completed this semester? Upload your marksheet to continue your scholarship.",
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadSemesterUpdateScreen(applicationId: applicationId),
                  ),
                );
              },
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text("Semester Updates"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}