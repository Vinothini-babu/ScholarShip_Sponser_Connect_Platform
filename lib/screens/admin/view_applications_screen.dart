import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ViewApplicationsScreen extends StatefulWidget {
  final String initialFilter;

  const ViewApplicationsScreen({
    super.key,
    this.initialFilter = "All",
  });

  @override
  State<ViewApplicationsScreen> createState() =>
      _ViewApplicationsScreenState();
}

class _ViewApplicationsScreenState
    extends State<ViewApplicationsScreen> {
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();

    _selectedFilter = widget.initialFilter;
  }

  // ============================================================
  // GET SPONSOR NAME
  // ============================================================

  Future<String> _getSponsorName(
      String sponsorId,
      ) async {
    if (sponsorId.isEmpty) {
      return "Unknown Sponsor";
    }

    try {
      final doc = await FirebaseFirestore
          .instance
          .collection("users")
          .doc(sponsorId)
          .get();

      if (doc.exists) {
        final data = doc.data();

        if (data != null) {
          final name =
          data["name"]?.toString();

          final organizationName =
          data["organizationName"]?.toString();

          if (organizationName != null &&
              organizationName.isNotEmpty) {
            return organizationName;
          }

          if (name != null &&
              name.isNotEmpty) {
            return name;
          }
        }
      }

      return "Unknown Sponsor";
    } catch (e) {
      debugPrint(
        "Sponsor fetch error: $e",
      );

      return "Unknown Sponsor";
    }
  }

  // ============================================================
  // DELETE APPLICATION
  // ============================================================

  Future<void> _deleteApplication(
      BuildContext context,
      String applicationId,
      ) async {
    final shouldDelete =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Delete Application",
          ),
          content: const Text(
            "Are you sure you want to delete this application?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                "Cancel",
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                "Delete",
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection("applications")
          .doc(applicationId)
          .delete();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Application deleted successfully",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
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

  // ============================================================
  // VIEW APPLICATION DETAILS
  // ============================================================

  void _showApplicationDetails(
      BuildContext context,
      Map<String, dynamic> data,
      ) {
    final studentName =
        data["studentName"]?.toString() ??
            "Unknown Student";

    final scholarshipTitle =
        data["scholarshipTitle"]?.toString() ??
            "Scholarship";

    final status =
        data["status"]?.toString() ??
            "Pending";

    final amount =
        data["amount"]?.toString() ??
            "0";

    final college =
        data["college"]?.toString() ??
            data["collegeName"]?.toString() ??
            "Not provided";

    final email =
        data["studentEmail"]?.toString() ??
            data["email"]?.toString() ??
            "Not provided";

    final mobile =
        data["mobile"]?.toString() ??
            data["phone"]?.toString() ??
            "Not provided";

    final sponsorName =
        data["sponsorName"]?.toString() ??
            "Unknown Sponsor";

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Application Details",
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  label: "Student",
                  value: studentName,
                ),

                _DetailRow(
                  label: "Scholarship",
                  value: scholarshipTitle,
                ),

                _DetailRow(
                  label: "Sponsor",
                  value: sponsorName,
                ),

                _DetailRow(
                  label: "College",
                  value: college,
                ),

                _DetailRow(
                  label: "Email",
                  value: email,
                ),

                _DetailRow(
                  label: "Mobile",
                  value: mobile,
                ),

                _DetailRow(
                  label: "Amount",
                  value: "₹$amount",
                ),

                _DetailRow(
                  label: "Status",
                  value: status,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Close",
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FILTER APPLICATIONS
  // ============================================================

  List<QueryDocumentSnapshot> _filterApplications(
      List<QueryDocumentSnapshot> docs,
      ) {
    if (_selectedFilter.toLowerCase() ==
        "all") {
      return docs;
    }

    return docs.where((doc) {
      final data =
      doc.data() as Map<String, dynamic>;

      final status =
          data["status"]?.toString().toLowerCase() ??
              "pending";

      return status ==
          _selectedFilter.toLowerCase();
    }).toList();
  }

  // ============================================================
  // PAGE TITLE
  // ============================================================

  String _pageTitle() {
    switch (_selectedFilter.toLowerCase()) {
      case "pending":
        return "Pending Applications";

      case "approved":
        return "Approved Applications";

      case "rejected":
        return "Rejected Applications";

      default:
        return "Student Applications";
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;

      case "rejected":
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Icons.check_circle_rounded;

      case "rejected":
        return Icons.cancel_rounded;

      default:
        return Icons.hourglass_top_rounded;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor:
        AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF1E3358),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          "View Applications",
          style: AppTextStyles.title.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("applications")
            .snapshots(),

        builder: (context, snapshot) {
          // ==========================================
          // LOADING
          // ==========================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ==========================================
          // ERROR
          // ==========================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                const EdgeInsets.all(24),
                child: Text(
                  "Something went wrong.\n\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style:
                  AppTextStyles.subtitle.copyWith(
                    color:
                    AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          // ==========================================
          // ALL DOCUMENTS
          // ==========================================

          final allDocs = [
            ...?snapshot.data?.docs,
          ];

          // ==========================================
          // SORT BY APPLIED DATE
          // ==========================================

          allDocs.sort((a, b) {
            final aData =
            a.data()
            as Map<String, dynamic>;

            final bData =
            b.data()
            as Map<String, dynamic>;

            final aDate =
            aData["appliedAt"];

            final bDate =
            bData["appliedAt"];

            if (aDate is Timestamp &&
                bDate is Timestamp) {
              return bDate.compareTo(aDate);
            }

            return 0;
          });

          // ==========================================
          // APPLY STATUS FILTER
          // ==========================================

          final filteredDocs =
          _filterApplications(
            allDocs,
          );

          // ==========================================
          // PAGE
          // ==========================================

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              40,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // ====================================
                // HEADING
                // ====================================

                Text(
                  _pageTitle(),
                  style:
                  AppTextStyles.title.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  _countText(
                    filteredDocs.length,
                  ),
                  style:
                  AppTextStyles.subtitle.copyWith(
                    color:
                    AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 22),

                // ====================================
                // EMPTY
                // ====================================

                if (filteredDocs.isEmpty)
                  _buildEmptyState()

                // ====================================
                // APPLICATIONS
                // ====================================

                else
                  Column(
                    children: filteredDocs
                        .map(
                          (doc) =>
                          _buildApplicationCard(
                            context,
                            doc,
                          ),
                    )
                        .toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // COUNT TEXT
  // ============================================================

  String _countText(int count) {
    if (_selectedFilter.toLowerCase() ==
        "all") {
      return "$count applications received";
    }

    return "$count ${_selectedFilter.toLowerCase()} applications found";
  }

  // ============================================================
  // APPLICATION CARD
  // ============================================================

  Widget _buildApplicationCard(
      BuildContext context,
      QueryDocumentSnapshot doc,
      ) {
    final data =
    doc.data() as Map<String, dynamic>;

    final studentName =
        data["studentName"]?.toString() ??
            "Unknown Student";

    final scholarshipTitle =
        data["scholarshipTitle"]?.toString() ??
            "Scholarship";

    final status =
        data["status"]?.toString() ??
            "Pending";

    final amount =
        data["amount"]?.toString() ??
            "0";

    final sponsorName =
    data["sponsorName"]?.toString();

    final sponsorId =
        data["sponsorId"]?.toString() ??
            data["sponsorID"]?.toString() ??
            "";

    final color =
    _statusColor(status);

    final statusIcon =
    _statusIcon(status);

    return FutureBuilder<String>(
      future: sponsorName != null &&
          sponsorName.isNotEmpty
          ? Future.value(sponsorName)
          : _getSponsorName(sponsorId),

      builder: (context, sponsorSnapshot) {
        final displaySponsor =
            sponsorSnapshot.data ??
                sponsorName ??
                "Unknown Sponsor";

        return Container(
          width: double.infinity,
          margin:
          const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:
                Colors.black.withOpacity(.05),
                blurRadius: 12,
                offset:
                const Offset(0, 5),
              ),
            ],
          ),

          child: Column(
            children: [
              // ========================================
              // TOP SECTION
              // ========================================

              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // Student Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withOpacity(.10),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        studentName.isNotEmpty
                            ? studentName[0]
                            .toUpperCase()
                            : "?",
                        style: TextStyle(
                          color:
                          AppColors.primary,
                          fontSize: 18,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Student Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style:
                          AppTextStyles.title
                              .copyWith(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Row(
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              size: 14,
                              color:
                              Colors.blueGrey,
                            ),

                            const SizedBox(
                              width: 6,
                            ),

                            Expanded(
                              child: Text(
                                scholarshipTitle,
                                style:
                                AppTextStyles
                                    .subtitle
                                    .copyWith(
                                  fontSize: 12,
                                  color:
                                  AppColors
                                      .textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 7),

                        Row(
                          children: [
                            const Icon(
                              Icons.business_rounded,
                              size: 14,
                              color:
                              Colors.blueGrey,
                            ),

                            const SizedBox(
                              width: 6,
                            ),

                            Expanded(
                              child: Text(
                                displaySponsor,
                                style:
                                AppTextStyles
                                    .subtitle
                                    .copyWith(
                                  fontSize: 12,
                                  color:
                                  AppColors
                                      .textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 7),

                        Row(
                          children: [
                            const Icon(
                              Icons
                                  .currency_rupee_rounded,
                              size: 14,
                              color:
                              Colors.blueGrey,
                            ),

                            const SizedBox(
                              width: 6,
                            ),

                            Text(
                              amount,
                              style:
                              AppTextStyles
                                  .subtitle
                                  .copyWith(
                                fontSize: 12,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ====================================
                  // STATUS
                  // ====================================

                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                      color.withOpacity(.10),
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
                          color: color,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

              ),

              const SizedBox(height: 18),

              // ========================================
              // BUTTONS
              // ========================================

              Row(
                children: [
                  // VIEW
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showApplicationDetails(
                          context,
                          {
                            ...data,
                            "sponsorName":
                            displaySponsor,
                          },
                        );
                      },
                      icon: const Icon(
                        Icons.visibility_rounded,
                        size: 17,
                      ),
                      label: const Text(
                        "View",
                      ),
                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor:
                        const Color(
                          0xFF1E3358,
                        ),
                        side:
                        const BorderSide(
                          color:
                          Color(0xFF1E3358),
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(10),
                        ),
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // DELETE
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _deleteApplication(
                          context,
                          doc.id,
                        );
                      },
                      icon: const Icon(
                        Icons.delete_rounded,
                        size: 17,
                      ),
                      label: const Text(
                        "Delete",
                      ),
                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(
                          0xFFEF6343,
                        ),
                        foregroundColor:
                        Colors.white,
                        elevation: 0,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(10),
                        ),
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 11,
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
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    String message;

    switch (_selectedFilter.toLowerCase()) {
      case "pending":
        message =
        "No pending applications found";

      case "approved":
        message =
        "No approved applications found";

      case "rejected":
        message =
        "No rejected applications found";

      default:
        message =
        "No applications found";
    }

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        vertical: 55,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 52,
            color:
            AppColors.textSecondary,
          ),

          const SizedBox(height: 14),

          Text(
            message,
            textAlign: TextAlign.center,
            style:
            AppTextStyles.title.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Applications will appear here when available.",
            textAlign: TextAlign.center,
            style:
            AppTextStyles.subtitle.copyWith(
              color:
              AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DETAIL ROW
// ============================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style:
              AppTextStyles.subtitle.copyWith(
                fontWeight:
                FontWeight.w600,
                color:
                AppColors.textSecondary,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style:
              AppTextStyles.subtitle.copyWith(
                color:
                const Color(0xFF1E3358),
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}