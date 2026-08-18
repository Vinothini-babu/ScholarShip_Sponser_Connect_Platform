import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/application_model.dart';
import '../../../services/application_service.dart';

class ApplicationDetailsScreen extends StatefulWidget {
  final ApplicationModel application;

  const ApplicationDetailsScreen({
    super.key,
    required this.application,
  });

  @override
  State<ApplicationDetailsScreen> createState() =>
      _ApplicationDetailsScreenState();
}

class _ApplicationDetailsScreenState
    extends State<ApplicationDetailsScreen> {

  final ApplicationService _applicationService =
  ApplicationService();

  bool _isUpdating = false;

  // =========================================================
  // UPDATE APPLICATION STATUS
  // =========================================================

  Future<void> _updateStatus(String status) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await _applicationService.updateApplicationStatus(
        applicationId: widget.application.id,
        status: status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == "Approved"
                ? "Application approved successfully"
                : "Application rejected successfully",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to update application: $e",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  // =========================================================
  // DATE
  // =========================================================

  String _formatDate() {
    final date =
    widget.application.appliedAt.toDate();

    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor() {
    switch (widget.application.status) {
      case "Approved":
        return AppColors.success;

      case "Rejected":
        return AppColors.error;

      default:
        return AppColors.warning;
    }
  }

  // =========================================================
  // STATUS ICON
  // =========================================================

  IconData _statusIcon() {
    switch (widget.application.status) {
      case "Approved":
        return Icons.check_circle_rounded;

      case "Rejected":
        return Icons.cancel_rounded;

      default:
        return Icons.hourglass_top_rounded;
    }
  }

  // =========================================================
  // INFO ROW
  // =========================================================

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 15),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          Container(
            width: 38,
            height: 38,

            decoration: BoxDecoration(
              color:
              AppColors.primary
                  .withOpacity(0.10),

              borderRadius:
              BorderRadius.circular(11),
            ),

            child: Icon(
              icon,
              size: 19,
              color:
              AppColors.primary,
            ),
          ),

          const SizedBox(width: 12),

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
                    fontSize: 11,
                    color:
                    AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value.isEmpty
                      ? "Not available"
                      : value,

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
      ),
    );
  }

  // =========================================================
  // SECTION CARD
  // =========================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,

      margin:
      const EdgeInsets.only(bottom: 16),

      padding:
      const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius:
        BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.05),

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

              Icon(
                icon,
                size: 21,
                color:
                AppColors.secondary,
              ),

              const SizedBox(width: 8),

              Text(
                title,

                style:
                AppTextStyles.title
                    .copyWith(
                  fontSize: 16,
                  color:
                  AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          child,
        ],
      ),
    );
  }

  Widget _uploadedDocumentsSection(
      Map<String, String> documents,
      ) {
    if (documents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 38,
              color: AppColors.textSecondary,
            ),

            const SizedBox(height: 10),

            Text(
              "No Documents Uploaded",
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "The student has not uploaded any documents.",
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: documents.entries.map((entry) {
        return _documentTile(
          label: _documentLabel(entry.key),
          path: entry.value,
        );
      }).toList(),
    );
  }

  String _documentLabel(String key) {
    switch (key) {
      case "marksheet":
        return "Marksheet";

      case "idProof":
        return "ID Proof";

      case "incomeCertificate":
        return "Income Certificate";

      case "collegeId":
        return "College ID";

      default:
        return key;
    }
  }



  Widget _documentTile({
    required String label,
    required String path,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.description_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            onPressed: () => _openDocument(path),
            icon: Icon(
              Icons.folder_open_rounded,
              color: AppColors.primary,
              size: 21,
            ),
            tooltip: "Open Document",
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(String path) async {
    if (path.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Document path is not available"),
        ),
      );
      return;
    }

    try {
      final file = File(path);

      if (!await file.exists()) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Document not found on this computer",
            ),
          ),
        );
        return;
      }

      final uri = Uri.file(file.path);

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to open document"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to open document: $e",
          ),
        ),
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {

    final application =
        widget.application;

    final statusColor =
    _statusColor();

    final isPending =
        application.status == "Pending";

    return Scaffold(
      backgroundColor:
      AppColors.background,

      appBar: AppBar(
        backgroundColor:
        AppColors.background,

        elevation: 0,

        centerTitle: true,

        iconTheme: IconThemeData(
          color:
          AppColors.textPrimary,
        ),

        title: Text(
          "Application Details",

          style:
          AppTextStyles.title.copyWith(
            fontSize: 18,
            color:
            AppColors.textPrimary,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),

        child: Column(
          children: [

            // =================================================
            // STUDENT INFORMATION
            // =================================================

            _sectionCard(
              title:
              "Student Information",

              icon:
              Icons.person_rounded,

              child: Column(
                children: [

                  _infoRow(
                    icon:
                    Icons.person_outline_rounded,

                    label:
                    "Student Name",

                    value:
                    application.studentName,
                  ),

                  _infoRow(
                    icon:
                    Icons.email_outlined,

                    label:
                    "Email",

                    value:
                    application.studentEmail,
                  ),

                  _infoRow(
                    icon:
                    Icons.account_balance_outlined,

                    label:
                    "College",

                    value:
                    application.studentCollege,
                  ),
                ],
              ),
            ),

            // =================================================
            // SCHOLARSHIP INFORMATION
            // =================================================

            _sectionCard(
              title:
              "Scholarship Information",

              icon:
              Icons.workspace_premium_rounded,

              child: Column(
                children: [

                  _infoRow(
                    icon:
                    Icons.school_outlined,

                    label:
                    "Scholarship",

                    value:
                    application.scholarshipTitle,
                  ),

                  _infoRow(
                    icon:
                    Icons.currency_rupee_rounded,

                    label:
                    "Scholarship Amount",

                    value:
                    application.amount,
                  ),

                  _infoRow(
                    icon:
                    Icons.calendar_today_outlined,

                    label:
                    "Applied Date",

                    value:
                    _formatDate(),
                  ),
                ],
              ),
            ),

            // =================================================
            // APPLICATION STATUS
            // =================================================

            _sectionCard(
              title:
              "Application Status",

              icon:
              Icons.info_outline_rounded,

              child: Container(
                width: double.infinity,

                padding:
                const EdgeInsets.all(15),

                decoration: BoxDecoration(
                  color:
                  statusColor
                      .withOpacity(0.10),

                  borderRadius:
                  BorderRadius.circular(14),
                ),

                child: Row(
                  children: [

                    Icon(
                      _statusIcon(),
                      color:
                      statusColor,
                    ),

                    const SizedBox(width: 10),

                    Text(
                      application.status,

                      style:
                      AppTextStyles.subtitle
                          .copyWith(
                        fontWeight:
                        FontWeight.bold,

                        color:
                        statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // UPLOADED DOCUMENTS
            // =================================================

            _sectionCard(
              title: "Uploaded Documents",
              icon: Icons.folder_copy_outlined,
              child: _uploadedDocumentsSection(
                application.documents,
              ),
            ),

            // =================================================
            // APPROVE / REJECT
            // =================================================

            if (isPending) ...[
              const SizedBox(height: 2),

              Row(
                children: [

                  // ------------------------------------------------
                  // REJECT
                  // ------------------------------------------------

                  Expanded(
                    child:
                    OutlinedButton.icon(
                      onPressed:
                      _isUpdating
                          ? null
                          : () =>
                          _updateStatus(
                            "Rejected",
                          ),

                      icon:
                      const Icon(
                        Icons.close_rounded,
                      ),

                      label:
                      const Text(
                        "Reject",
                      ),

                      style:
                      OutlinedButton
                          .styleFrom(
                        foregroundColor:
                        AppColors.error,

                        side:
                        BorderSide(
                          color:
                          AppColors.error,
                          width: 1.3,
                        ),

                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 14,
                        ),

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                              14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ------------------------------------------------
                  // APPROVE
                  // ------------------------------------------------

                  Expanded(
                    child:
                    ElevatedButton.icon(
                      onPressed:
                      _isUpdating
                          ? null
                          : () =>
                          _updateStatus(
                            "Approved",
                          ),

                      icon:
                      _isUpdating
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                          color:
                          Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons
                            .check_rounded,
                      ),

                      label:
                      const Text(
                        "Approve",
                      ),

                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        AppColors.success,

                        foregroundColor:
                        Colors.white,

                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 14,
                        ),

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                              14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}