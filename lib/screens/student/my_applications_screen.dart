import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'application_details_screen.dart';

class MyApplicationsScreen extends StatelessWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "My Applications",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: currentUser == null
          ? Center(
        child: Text("Please login again", style: AppTextStyles.subtitle),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("applications")
            .where("studentId", isEqualTo: currentUser.uid)
            .orderBy("appliedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 60, color: AppColors.textSecondary),
                  const SizedBox(height: 14),
                  Text(
                    "No Applications Yet",
                    style: AppTextStyles.title.copyWith(fontSize: 17, color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final applicationId = doc.id;

              return _buildCard(context, data, applicationId);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(
      BuildContext context,
      Map<String, dynamic> data,
      String applicationId,
      ) {
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

    String appliedDate = "Date not available";
    if (data["appliedAt"] is Timestamp) {
      final Timestamp timestamp = data["appliedAt"] as Timestamp;
      final DateTime date = timestamp.toDate();
      appliedDate =
      "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  data["scholarshipTitle"]?.toString() ?? "Scholarship",
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _DetailRow(
            icon: Icons.currency_rupee_rounded,
            text: data["amount"]?.toString() ?? "Amount not available",
            bold: true,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.account_balance_rounded,
            text: data["studentCollege"]?.toString() ?? "College not available",
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.email_outlined,
            text: data["studentEmail"]?.toString() ?? "",
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            text: "Applied: $appliedDate",
            muted: true,
          ),

          const SizedBox(height: 16),
          Divider(color: AppColors.textSecondary.withOpacity(0.15)),
          const SizedBox(height: 12),

          // Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Application Status",
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
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
                          : Icons.access_time_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: AppTextStyles.subtitle.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // View Details
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApplicationDetailsScreen(
                      data: data,
                      applicationId: applicationId,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.visibility_outlined, color: AppColors.primary, size: 19),
              label: Text("View Details", style: TextStyle(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary, width: 1.4),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
  final String text;
  final bool bold;
  final bool muted;

  const _DetailRow({
    required this.icon,
    required this.text,
    this.bold = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: muted ? 16 : 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: muted ? 12 : 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
