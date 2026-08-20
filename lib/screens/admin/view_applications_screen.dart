import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ViewApplicationsScreen extends StatelessWidget {
  const ViewApplicationsScreen({super.key});

  // ============================================================
  // GET SPONSOR NAME
  // ============================================================

  Future<String> _getSponsorName(String sponsorId) async {
    if (sponsorId.trim().isEmpty) {
      return "Unknown Sponsor";
    }

    try {
      // --------------------------------------------------------
      // 1. YOUR CURRENT STRUCTURE
      //
      // users
      //   └── sponsor
      //        └── sponsorId
      //             └── profile
      // --------------------------------------------------------

      final nestedDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc("sponsor")
          .collection(sponsorId)
          .doc("profile")
          .get();

      if (nestedDoc.exists) {
        final data = nestedDoc.data();

        if (data != null) {
          final name = data["name"]?.toString().trim();
          final organizationName =
          data["organizationName"]?.toString().trim();

          if (name != null && name.isNotEmpty) {
            return name;
          }

          if (organizationName != null &&
              organizationName.isNotEmpty) {
            return organizationName;
          }
        }
      }

      // --------------------------------------------------------
      // 2. ROOT USER STRUCTURE
      //
      // users
      //   └── sponsorId
      //        └── name
      // --------------------------------------------------------

      final rootDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(sponsorId)
          .get();

      if (rootDoc.exists) {
        final data = rootDoc.data();

        if (data != null) {
          final name = data["name"]?.toString().trim();
          final organizationName =
          data["organizationName"]?.toString().trim();

          if (name != null && name.isNotEmpty) {
            return name;
          }

          if (organizationName != null &&
              organizationName.isNotEmpty) {
            return organizationName;
          }
        }
      }

      return "Unknown Sponsor";
    } catch (e) {
      debugPrint("Sponsor fetch error: $e");
      return "Unknown Sponsor";
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,

        title: Text(
          "View Applications",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),

        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      // ========================================================
      // REAL-TIME APPLICATIONS
      // ========================================================

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("applications")
            .snapshots(),

        builder: (context, snapshot) {
          // ----------------------------------------------------
          // LOADING
          // ----------------------------------------------------

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ----------------------------------------------------
          // ERROR
          // ----------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Error loading applications:\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            );
          }

          // ----------------------------------------------------
          // GET APPLICATIONS
          // ----------------------------------------------------

          final applications =
              snapshot.data?.docs ?? [];

          // ----------------------------------------------------
          // NO APPLICATIONS
          // ----------------------------------------------------

          if (applications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 60,
                    color: AppColors.textSecondary,
                  ),

                  const SizedBox(height: 14),

                  Text(
                    "No Applications Found",
                    style: AppTextStyles.title.copyWith(
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "No scholarship applications have been received yet.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                ],
              ),
            );
          }

          // ====================================================
          // APPLICATION LIST
          // ====================================================

          return ListView(
            padding: const EdgeInsets.all(20),

            children: [
              // ------------------------------------------------
              // TITLE
              // ------------------------------------------------

              Text(
                "Student Applications",
                style: AppTextStyles.title.copyWith(
                  fontSize: 22,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              // ------------------------------------------------
              // REAL COUNT
              // ------------------------------------------------

              Text(
                "${applications.length} applications received",
                style: AppTextStyles.subtitle,
              ),

              const SizedBox(height: 22),

              // ------------------------------------------------
              // APPLICATION CARDS
              // ------------------------------------------------

              ...applications.map((application) {
                final data =
                application.data()
                as Map<String, dynamic>;

                // Student
                final studentName =
                    data["studentName"]?.toString() ??
                        data["name"]?.toString() ??
                        "Unknown Student";

                // Scholarship
                final scholarshipTitle =
                    data["scholarshipTitle"]?.toString() ??
                        data["scholarshipName"]?.toString() ??
                        "Unknown Scholarship";

                // Sponsor ID
                final sponsorId =
                    data["sponsorId"]?.toString() ?? "";

                // Status
                final status =
                    data["status"]?.toString() ??
                        "Pending";

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16,
                  ),

                  child: FutureBuilder<String>(
                    future: _getSponsorName(sponsorId),

                    builder:
                        (context, sponsorSnapshot) {
                      final sponsorName =
                      sponsorSnapshot.connectionState ==
                          ConnectionState.waiting
                          ? "Loading Sponsor..."
                          : sponsorSnapshot.data ??
                          "Unknown Sponsor";

                      return _buildApplicationCard(
                        context,

                        documentId:
                        application.id,

                        student:
                        studentName,

                        scholarship:
                        scholarshipTitle,

                        sponsor:
                        sponsorName,

                        status:
                        status,

                        applicationData:
                        data,
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // APPLICATION CARD
  // ============================================================

  Widget _buildApplicationCard(
      BuildContext context, {
        required String documentId,
        required String student,
        required String scholarship,
        required String sponsor,
        required String status,
        required Map<String, dynamic> applicationData,
      }) {
    // ==========================================================
    // STATUS COLOR + ICON
    // ==========================================================

    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case "approved":
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;

      case "rejected":
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;

      case "pending":
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_top_rounded;
        break;

      default:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.info_rounded;
    }

    // ==========================================================
    // CARD
    // ==========================================================

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
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // ====================================================
          // STUDENT + STATUS
          // ====================================================

          Row(
            children: [
              // ------------------------------------------------
              // STUDENT AVATAR
              // ------------------------------------------------

              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  color: AppColors.secondary
                      .withOpacity(0.15),

                  shape: BoxShape.circle,
                ),

                child: Center(
                  child: Text(
                    student.isNotEmpty
                        ? student[0].toUpperCase()
                        : "?",

                    style:
                    AppTextStyles.title.copyWith(
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // ------------------------------------------------
              // STUDENT NAME
              // ------------------------------------------------

              Expanded(
                child: Text(
                  student,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),

              // ------------------------------------------------
              // STATUS
              // ------------------------------------------------

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: statusColor
                      .withOpacity(0.12),

                  borderRadius:
                  BorderRadius.circular(20),
                ),

                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [
                    Icon(
                      statusIcon,
                      size: 13,
                      color: statusColor,
                    ),

                    const SizedBox(width: 5),

                    Text(
                      _formatStatus(status),

                      style: AppTextStyles.subtitle
                          .copyWith(
                        color: statusColor,
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ====================================================
          // SCHOLARSHIP
          // ====================================================

          Row(
            children: [
              Icon(
                Icons.school_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 5),

              Expanded(
                child: Text(
                  scholarship,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                  ),

                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // ====================================================
          // SPONSOR
          // ====================================================

          Row(
            children: [
              Icon(
                Icons.business_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 5),

              Expanded(
                child: Text(
                  sponsor,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                  ),

                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ====================================================
          // BUTTONS
          // ====================================================

          Row(
            children: [
              // ------------------------------------------------
              // VIEW
              // ------------------------------------------------

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showApplicationDetails(
                      context,
                      student,
                      scholarship,
                      sponsor,
                      status,
                      applicationData,
                    );
                  },

                  icon: Icon(
                    Icons.visibility_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),

                  label: Text(
                    "View",
                    style: TextStyle(
                      color: AppColors.primary,
                    ),
                  ),

                  style:
                  OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),

                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 12,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ------------------------------------------------
              // DELETE
              // ------------------------------------------------

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _deleteApplication(
                      context,
                      documentId,
                      student,
                    );
                  },

                  icon: const Icon(
                    Icons.delete_rounded,
                    size: 17,
                  ),

                  label:
                  const Text("Delete"),

                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.error,

                    foregroundColor:
                    Colors.white,

                    elevation: 0,

                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 12,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
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

  // ============================================================
  // FORMAT STATUS
  // ============================================================

  String _formatStatus(String status) {
    if (status.isEmpty) {
      return "Pending";
    }

    return status[0].toUpperCase() +
        status.substring(1).toLowerCase();
  }

  // ============================================================
  // VIEW APPLICATION DETAILS
  // ============================================================

  void _showApplicationDetails(
      BuildContext context,
      String student,
      String scholarship,
      String sponsor,
      String status,
      Map<String, dynamic> data,
      ) {
    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text(
            "Application Details",
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  "👤 Student : $student",
                ),

                const SizedBox(height: 10),

                Text(
                  "🎓 Scholarship : $scholarship",
                ),

                const SizedBox(height: 10),

                Text(
                  "🏢 Sponsor : $sponsor",
                ),

                const SizedBox(height: 10),

                Text(
                  "📌 Status : ${_formatStatus(status)}",
                ),

                // --------------------------------------------
                // STUDENT EMAIL
                // --------------------------------------------

                if (data["studentEmail"] != null) ...[
                  const SizedBox(height: 10),

                  Text(
                    "📧 Email : ${data["studentEmail"]}",
                  ),
                ],

                // --------------------------------------------
                // STUDENT COLLEGE
                // --------------------------------------------

                if (data["studentCollege"] != null) ...[
                  const SizedBox(height: 10),

                  Text(
                    "🏫 College : ${data["studentCollege"]}",
                  ),
                ],

                // --------------------------------------------
                // AMOUNT
                // --------------------------------------------

                if (data["amount"] != null) ...[
                  const SizedBox(height: 10),

                  Text(
                    "💰 Amount : ₹${data["amount"]}",
                  ),
                ],

                // --------------------------------------------
                // APPLIED DATE
                // --------------------------------------------

                if (data["appliedAt"] != null) ...[
                  const SizedBox(height: 10),

                  Text(
                    "📅 Applied At : ${_formatAppliedDate(data["appliedAt"])}",
                  ),
                ],
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FORMAT APPLIED DATE
  // ============================================================

  String _formatAppliedDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      return "${date.day.toString().padLeft(2, '0')}/"
          "${date.month.toString().padLeft(2, '0')}/"
          "${date.year} "
          "${date.hour.toString().padLeft(2, '0')}:"
          "${date.minute.toString().padLeft(2, '0')}";
    }

    return value.toString();
  }

  // ============================================================
  // DELETE APPLICATION
  // ============================================================

  Future<void> _deleteApplication(
      BuildContext context,
      String documentId,
      String student,
      ) async {
    // ----------------------------------------------------------
    // CONFIRMATION
    // ----------------------------------------------------------

    final bool? confirm =
    await showDialog<bool>(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text(
            "Delete Application",
          ),

          content: Text(
            "Are you sure you want to delete $student's application?",
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },

              child: const Text(
                "Cancel",
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.error,

                foregroundColor:
                Colors.white,
              ),

              child: const Text(
                "Delete",
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    // ----------------------------------------------------------
    // DELETE FROM FIRESTORE
    // ----------------------------------------------------------

    try {
      await FirebaseFirestore.instance
          .collection("applications")
          .doc(documentId)
          .delete();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "$student's application deleted successfully 🗑️",
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete application: $e",
          ),
        ),
      );
    }
  }
}