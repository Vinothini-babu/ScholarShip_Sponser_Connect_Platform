import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ApplicationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String applicationId;

  const ApplicationDetailsScreen({
    super.key,
    required this.data,
    required this.applicationId,
  });

  @override
  State<ApplicationDetailsScreen> createState() => _ApplicationDetailsScreenState();
}

class _ApplicationDetailsScreenState extends State<ApplicationDetailsScreen> {
  Future<void> updateStatus(String status, Map<String, dynamic> currentData) async {
    if (status == "Approved" && currentData["documentsVerified"] != true) {
      final proceed = await _confirmApproveWithoutVerification();
      if (!proceed) return;
    }

    await FirebaseFirestore.instance.collection("applications").doc(widget.applicationId).update({
      "status": status,
      "statusHistory": FieldValue.arrayUnion([
        {"status": status, "timestamp": Timestamp.now()},
      ]),
    });
  }

  Future<bool> _confirmApproveWithoutVerification() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Documents not verified"),
        content: const Text(
          "You haven't marked the uploaded documents as verified yet. "
              "Approve this application anyway?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Go back")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Approve anyway"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _toggleDocumentsVerified(bool value) async {
    await FirebaseFirestore.instance.collection("applications").doc(widget.applicationId).update({
      "documentsVerified": value,
      "documentsVerifiedAt": value ? Timestamp.now() : null,
    });
  }

  Future<void> _openFieldVerificationDialog(bool alreadyVerified) async {
    final noteController = TextEditingController();
    final verifiedByController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alreadyVerified ? "Update Field Verification" : "Mark as Field Verified"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Confirm this only after physically meeting the student and cross-checking their original documents.",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: verifiedByController,
              decoration: const InputDecoration(
                labelText: "Verified by",
                hintText: "e.g. Mrs. Kavitha, Program Coordinator",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Note (optional)",
                hintText: "e.g. Verified Aadhaar & income certificate originals",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection("applications").doc(widget.applicationId).update({
      "fieldVerified": true,
      "fieldVerifiedBy": verifiedByController.text.trim().isEmpty ? "Not specified" : verifiedByController.text.trim(),
      "fieldVerifiedNote": noteController.text.trim(),
      "fieldVerifiedAt": Timestamp.now(),
    });
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open this document")),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Application Details",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      // Live document stream so verification/status changes reflect instantly —
      // falls back to the data passed in until the first snapshot arrives.
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("applications").doc(widget.applicationId).snapshots(),
        builder: (context, snapshot) {
          final Map<String, dynamic> data = snapshot.hasData && snapshot.data!.exists
              ? (snapshot.data!.data() as Map<String, dynamic>)
              : widget.data;

          final String status = data["status"] ?? "Pending";

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
          if (data["appliedAt"] != null && data["appliedAt"] is Timestamp) {
            final date = (data["appliedAt"] as Timestamp).toDate();
            appliedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
          }

          final bool documentsVerified = data["documentsVerified"] == true;
          final bool fieldVerified = data["fieldVerified"] == true;
          final Map<String, dynamic> documents =
          (data["documents"] is Map) ? Map<String, dynamic>.from(data["documents"]) : {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scholarship header
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(Icons.school_rounded, color: AppColors.primary, size: 27),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              data["scholarshipTitle"] ?? "Scholarship",
                              style: AppTextStyles.title.copyWith(fontSize: 19, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: AppColors.textSecondary.withOpacity(0.15)),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.currency_rupee_rounded,
                        label: "Scholarship Amount",
                        value: data["amount"] ?? "Amount not available",
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: "Applied Date",
                        value: appliedDate,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text("Student Information", style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary)),
                const SizedBox(height: 12),

                _Card(
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: "Name",
                        value: data["studentName"] ?? "Name not available",
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: "Email",
                        value: data["studentEmail"] ?? "Email not available",
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.account_balance_rounded,
                        label: "College",
                        value: data["studentCollege"] ?? "College not available",
                      ),
                    ],
                  ),
                ),

                // Full student profile (category, income, year, roll number etc.)
                // fetched live from users/{studentId} when the application
                // references the student's uid.
                if (data["studentId"] != null || data["uid"] != null) ...[
                  const SizedBox(height: 12),
                  _StudentProfileCard(studentId: (data["studentId"] ?? data["uid"]).toString()),
                ],

                const SizedBox(height: 20),
                Text("Uploaded Documents", style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary)),
                const SizedBox(height: 12),

                _Card(
                  padding: EdgeInsets.zero,
                  child: documents.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: Text("No documents uploaded yet")),
                  )
                      : Column(
                    children: [
                      for (int i = 0; i < documents.length; i++) ...[
                        _DocumentRow(
                          name: documents.keys.elementAt(i),
                          url: documents.values.elementAt(i).toString(),
                          onView: () => _openDocument(documents.values.elementAt(i).toString()),
                        ),
                        if (i != documents.length - 1)
                          Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text("Document Verification", style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary)),
                const SizedBox(height: 12),

                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: documentsVerified,
                        onChanged: _toggleDocumentsVerified,
                        activeColor: AppColors.success,
                        title: const Text("Documents Verified", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                          "You've reviewed the uploaded documents online and they look genuine.",
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      Divider(color: AppColors.textSecondary.withOpacity(0.12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            fieldVerified ? Icons.verified_rounded : Icons.pending_outlined,
                            color: fieldVerified ? AppColors.success : AppColors.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fieldVerified ? "Field Verified" : "Not field-verified yet",
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (fieldVerified) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "By ${data["fieldVerifiedBy"] ?? "—"}"
                                        "${(data["fieldVerifiedNote"] ?? "").toString().isNotEmpty ? " · ${data["fieldVerifiedNote"]}" : ""}",
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _openFieldVerificationDialog(fieldVerified),
                            child: Text(fieldVerified ? "Update" : "Mark Verified"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text("Application Status", style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary)),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
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
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status,
                              style: AppTextStyles.subtitle.copyWith(color: statusColor, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status == "Approved"
                                  ? "Your application has been approved."
                                  : status == "Rejected"
                                  ? "Your application has been rejected."
                                  : "Your application is under review.",
                              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _Card(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.fingerprint_rounded, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Application ID", style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              widget.applicationId,
                              style: AppTextStyles.subtitle.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: status == "Approved" ? null : () => updateStatus("Approved", data),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text("Approve"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.success.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: status == "Rejected" ? null : () => updateStatus("Rejected", data),
                        icon: Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                        label: Text("Reject", style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error, width: 1.4),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==============================
// Shared card shell
// ==============================
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

// ==============================
// Uploaded document row — tap "View" to open the file
// ==============================
class _DocumentRow extends StatelessWidget {
  final String name;
  final String url;
  final VoidCallback onView;
  const _DocumentRow({required this.name, required this.url, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          TextButton.icon(
            onPressed: onView,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text("View"),
          ),
        ],
      ),
    );
  }
}

// ==============================
// Full student profile, fetched from users/{studentId}
// ==============================
class _StudentProfileCard extends StatelessWidget {
  final String studentId;
  const _StudentProfileCard({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection("users").doc(studentId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        final profile = snapshot.data!.data() as Map<String, dynamic>;
        final rows = <Widget>[];

        void addIfPresent(IconData icon, String label, dynamic value) {
          if (value == null || value.toString().isEmpty) return;
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 14));
          rows.add(_InfoRow(icon: icon, label: label, value: value.toString()));
        }

        addIfPresent(Icons.groups_outlined, "Category", profile["category"]);
        addIfPresent(Icons.timeline_outlined, "Year of Study", profile["yearOfStudy"]);
        addIfPresent(Icons.badge_outlined, "Roll / Register Number", profile["rollNumber"]);
        addIfPresent(Icons.currency_rupee_rounded, "Annual Family Income", profile["annualIncome"]);
        addIfPresent(Icons.map_outlined, "State", profile["state"]);
        addIfPresent(Icons.location_city_outlined, "District", profile["district"]);

        if (rows.isEmpty) return const SizedBox.shrink();

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Eligibility Profile", style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              ...rows,
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTextStyles.subtitle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}