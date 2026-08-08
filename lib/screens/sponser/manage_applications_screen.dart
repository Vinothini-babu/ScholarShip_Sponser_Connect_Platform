import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ManageApplicationsScreen extends StatelessWidget {
  const ManageApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Manage Applications",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("applications")
            .where(
          "sponsorId",
          isEqualTo: FirebaseAuth.instance.currentUser!.uid,
        )
            .orderBy("appliedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Error: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.error),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 60, color: AppColors.textSecondary),
                  const SizedBox(height: 14),
                  Text(
                    "No Applications Found",
                    style: AppTextStyles.title.copyWith(fontSize: 17, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Applications from students will appear here.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final application = doc.data() as Map<String, dynamic>;

              final studentName = application["studentName"] ?? "Unknown Student";
              final studentEmail = application["studentEmail"] ?? "No Email";
              final studentCollege = application["studentCollege"] ?? "Not Provided";
              final scholarshipTitle = application["scholarshipTitle"] ?? "Scholarship";
              final amount = application["amount"] ?? "0";
              final status = application["status"] ?? "Pending";
              final appliedAt = application["appliedAt"] as Timestamp?;

              String appliedDate = "Date not available";
              if (appliedAt != null) {
                final date = appliedAt.toDate();
                appliedDate =
                "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
              }

              Color statusColor;
              if (status == "Approved") {
                statusColor = AppColors.success;
              } else if (status == "Rejected") {
                statusColor = AppColors.error;
              } else {
                statusColor = AppColors.warning;
              }

              Future<void> _updateStatus(String newStatus) async {
                try {
                  await FirebaseFirestore.instance
                      .collection("applications")
                      .doc(doc.id)
                      .update({"status": newStatus});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$studentName $newStatus")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.textSecondary.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scholarship title
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(Icons.school_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            scholarshipTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title.copyWith(fontSize: 17, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _InfoRow(icon: Icons.person_rounded, label: "Student", value: studentName, bold: true),
                    const SizedBox(height: 14),
                    _InfoRow(icon: Icons.email_rounded, label: "Email", value: studentEmail),
                    const SizedBox(height: 14),
                    _InfoRow(icon: Icons.school_outlined, label: "College", value: studentCollege),

                    const SizedBox(height: 18),

                    // Amount + Applied date
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.currency_rupee_rounded,
                            label: "Amount",
                            value: amount,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.calendar_today_rounded,
                            label: "Applied",
                            value: appliedDate,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == "Approved"
                                ? Icons.check_circle
                                : status == "Rejected"
                                ? Icons.cancel
                                : Icons.pending_rounded,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: AppTextStyles.subtitle.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Approve & Reject buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: status == "Approved" ? null : () => _updateStatus("Approved"),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text("Approve"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.success.withOpacity(0.4),
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
                            onPressed: status == "Rejected" ? null : () => _updateStatus("Rejected"),
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
            },
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool bold;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.subtitle.copyWith(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 10, color: AppColors.textSecondary),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
