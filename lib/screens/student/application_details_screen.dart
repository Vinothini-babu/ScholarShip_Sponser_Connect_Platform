import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: Text(
          "Application Details",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("applications")
            .doc(applicationId)
            .snapshots(),

        builder: (context, snapshot) {

          // ==========================================
          // LOADING
          // ==========================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          // ==========================================
          // ERROR
          // ==========================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Text(
                  "Something went wrong.\n\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            );
          }

          // ==========================================
          // APPLICATION NOT FOUND
          // ==========================================

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text(
                "Application not found",
              ),
            );
          }

          // ==========================================
          // 🔥 REAL-TIME FIRESTORE DATA
          // ==========================================

          final latestData =
              snapshot.data!.data() ?? {};

          // ==========================================
          // STATUS
          // ==========================================

          final String status =
              latestData["status"]
                  ?.toString() ??
                  "Pending";

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

          // ==========================================
          // APPLIED DATE
          // ==========================================

          String appliedDate =
              "Date not available";

          if (latestData["appliedAt"]
          is Timestamp) {

            final Timestamp timestamp =
            latestData["appliedAt"]
            as Timestamp;

            final DateTime date =
            timestamp.toDate();

            appliedDate =
            "${date.day.toString().padLeft(2, '0')}/"
                "${date.month.toString().padLeft(2, '0')}/"
                "${date.year}";
          }

          // ==========================================
          // MAIN CONTENT
          // ==========================================

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                // ====================================
                // SCHOLARSHIP INFORMATION
                // ====================================

                Container(
                  width: double.infinity,

                  padding:
                  const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: AppColors.card,

                    borderRadius:
                    BorderRadius.circular(20),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.05),

                        blurRadius: 12,

                        offset:
                        const Offset(0, 5),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      Row(
                        children: [

                          Container(
                            width: 52,
                            height: 52,

                            decoration:
                            BoxDecoration(
                              color: AppColors
                                  .primary
                                  .withOpacity(0.10),

                              borderRadius:
                              BorderRadius
                                  .circular(15),
                            ),

                            child: Icon(
                              Icons.school_rounded,
                              color:
                              AppColors.primary,
                              size: 27,
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          Expanded(
                            child: Text(
                              latestData[
                              "scholarshipTitle"]
                                  ?.toString() ??
                                  "Scholarship",

                              style:
                              AppTextStyles
                                  .title
                                  .copyWith(
                                fontSize: 19,
                                color: AppColors
                                    .textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      Divider(
                        color: AppColors
                            .textSecondary
                            .withOpacity(0.15),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      _InfoRow(
                        icon: Icons
                            .currency_rupee_rounded,

                        label:
                        "Scholarship Amount",

                        value: latestData[
                        "amount"]
                            ?.toString() ??
                            "Amount not available",
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      _InfoRow(
                        icon: Icons
                            .calendar_today_rounded,

                        label:
                        "Applied Date",

                        value: appliedDate,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ====================================
                // STUDENT INFORMATION
                // ====================================

                Text(
                  "Student Information",

                  style:
                  AppTextStyles.title.copyWith(
                    fontSize: 18,
                    color:
                    AppColors.textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Container(
                  width: double.infinity,

                  padding:
                  const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: AppColors.card,

                    borderRadius:
                    BorderRadius.circular(20),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.05),

                        blurRadius: 12,

                        offset:
                        const Offset(0, 5),
                      ),
                    ],
                  ),

                  child: Column(
                    children: [

                      _InfoRow(
                        icon: Icons
                            .person_outline_rounded,

                        label: "Name",

                        value: latestData[
                        "studentName"]
                            ?.toString() ??
                            "Name not available",
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      _InfoRow(
                        icon: Icons
                            .email_outlined,

                        label: "Email",

                        value: latestData[
                        "studentEmail"]
                            ?.toString() ??
                            "Email not available",
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      _InfoRow(
                        icon: Icons
                            .account_balance_rounded,

                        label: "College",

                        value: latestData[
                        "studentCollege"]
                            ?.toString() ??
                            "College not available",
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ====================================
                // APPLICATION STATUS
                // ====================================

                Text(
                  "Application Status",

                  style:
                  AppTextStyles.title.copyWith(
                    fontSize: 18,
                    color:
                    AppColors.textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Container(
                  width: double.infinity,

                  padding:
                  const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color:
                    statusColor.withOpacity(
                      0.08,
                    ),

                    borderRadius:
                    BorderRadius.circular(20),

                    border: Border.all(
                      color:
                      statusColor.withOpacity(
                        0.25,
                      ),
                    ),
                  ),

                  child: Row(
                    children: [

                      // STATUS ICON
                      Icon(
                        status == "Approved"
                            ? Icons.check_circle
                            : status == "Rejected"
                            ? Icons.cancel
                            : Icons
                            .access_time_rounded,

                        color: statusColor,

                        size: 28,
                      ),

                      const SizedBox(
                        width: 14,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [

                            Text(
                              status,

                              style:
                              AppTextStyles
                                  .subtitle
                                  .copyWith(
                                color:
                                statusColor,

                                fontSize: 17,

                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              status == "Approved"
                                  ? "Your application has been approved."
                                  : status == "Rejected"
                                  ? "Your application has been rejected."
                                  : "Your application is under review.",

                              style:
                              AppTextStyles
                                  .subtitle
                                  .copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ====================================
                // APPLICATION ID
                // ====================================

                Container(
                  width: double.infinity,

                  padding:
                  const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: AppColors.card,

                    borderRadius:
                    BorderRadius.circular(15),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.04),

                        blurRadius: 8,

                        offset:
                        const Offset(0, 3),
                      ),
                    ],
                  ),

                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      Icon(
                        Icons.fingerprint_rounded,

                        color:
                        AppColors.textSecondary,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [

                            Text(
                              "Application ID",

                              style:
                              AppTextStyles
                                  .subtitle
                                  .copyWith(
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              applicationId,

                              style:
                              AppTextStyles
                                  .subtitle
                                  .copyWith(
                                fontSize: 13,

                                fontWeight:
                                FontWeight.w600,

                                color: AppColors
                                    .textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


// ======================================================
// INFO ROW
// ======================================================

class _InfoRow extends StatelessWidget {

  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [

        Icon(
          icon,
          size: 20,
          color:
          AppColors.textSecondary,
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              Text(
                label,

                style:
                AppTextStyles.subtitle
                    .copyWith(
                  fontSize: 12,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                value,

                style:
                AppTextStyles.subtitle
                    .copyWith(
                  fontSize: 14,

                  fontWeight:
                  FontWeight.w600,

                  color:
                  AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}