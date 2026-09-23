import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

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

class _ApplicationDetailsScreenState extends State<ApplicationDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  // Number of top-level sections that get a staggered entrance — kept as a
  // constant divisor so the reveal timing stays even regardless of which
  // optional sections (score/statement/eligibility profile) are present.
  // NOTE: the new "Semester Updates" section (below Document Verification)
  // isn't wrapped in _reveal — it's driven by its own StreamBuilder and can
  // grow/shrink as submissions come in, so it's left out of the staggered
  // count rather than shifting every other section's timing.
  static const int _sectionCount = 10;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  /// Fade + slide-up entrance, staggered by [index]. Only plays once on
  /// first build — later StreamBuilder rebuilds (e.g. toggling a verify
  /// switch) don't replay it, since the controller has already finished.
  Widget _reveal(int index, Widget child) {
    final start = (index / _sectionCount) * 0.6;
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }

  Future<void> updateStatus(String status, Map<String, dynamic> currentData) async {
    if (status == "Approved" && currentData["documentsVerified"] != true) {
      final proceed = await _confirmApproveWithoutVerification();
      if (!proceed) return;
    }

    final Map<String, dynamic> updateData = {
      "status": status,
      "statusHistory": FieldValue.arrayUnion([
        {"status": status, "timestamp": Timestamp.now()},
      ]),
    };

    // First time this application is approved, initialize semester-renewal
    // tracking so the student's "Upload Next Semester Marks" screen and
    // this screen's "Semester Updates" section both have a starting point.
    if (status == "Approved" && currentData["currentSemester"] == null) {
      updateData["currentSemester"] = 1;
      updateData["scholarshipStatus"] = "Active";
    }

    await FirebaseFirestore.instance.collection("applications").doc(widget.applicationId).update(updateData);
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

  Future<void> _toggleDocumentsVerified(bool value, Map<String, dynamic> currentData) async {
    // Documents are worth 20 of the 100-point evaluation score — recompute
    // the total whenever this is toggled, since academic/income scores
    // were already calculated at apply time.
    final academicScore = (currentData["academicScore"] is num) ? (currentData["academicScore"] as num).toDouble() : 0.0;
    final incomeScore = (currentData["incomeScore"] is num) ? (currentData["incomeScore"] as num).toDouble() : 0.0;
    final documentsScore = value ? 20.0 : 0.0;

    try {
      await FirebaseFirestore.instance.collection("applications").doc(widget.applicationId).update({
        "documentsVerified": value,
        "documentsVerifiedAt": value ? Timestamp.now() : null,
        "documentsScore": documentsScore,
        "totalScore": academicScore + incomeScore + documentsScore,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't update: $e")),
      );
    }
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

  // ==============================
  // SEMESTER UPDATES — Approve/Reject a student's per-semester marks
  // submission. Approve bumps the application's currentSemester so the
  // student's next "Upload Next Semester Marks" screen unlocks. Reject
  // stores the sponsor's remarks (shown back to the student) and,
  // optionally, suspends the scholarship entirely.
  // ==============================

  Future<void> _approveSemesterUpdate(int semesterNumber) async {
    final appRef = FirebaseFirestore.instance.collection("applications").doc(widget.applicationId);
    final semRef = appRef.collection("semesterUpdates").doc(semesterNumber.toString());

    final batch = FirebaseFirestore.instance.batch();
    batch.update(semRef, {
      "status": "Approved",
      "reviewedAt": Timestamp.now(),
    });
    batch.update(appRef, {
      "currentSemester": semesterNumber + 1,
    });
    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Semester $semesterNumber approved — student can now submit semester ${semesterNumber + 1}.")),
    );
  }

  Future<void> _rejectSemesterUpdate(int semesterNumber) async {
    final remarksController = TextEditingController();
    bool suspendScholarship = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Reject Semester $semesterNumber Update"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: remarksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Remarks for the student",
                  hintText: "e.g. Marksheet image is unclear, please re-upload",
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: suspendScholarship,
                onChanged: (v) => setDialogState(() => suspendScholarship = v ?? false),
                title: const Text("Suspend scholarship", style: TextStyle(fontSize: 13.5)),
                subtitle: const Text(
                  "Use this only if the student no longer qualifies (e.g. marks dropped below eligibility).",
                  style: TextStyle(fontSize: 11.5),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Reject"),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final appRef = FirebaseFirestore.instance.collection("applications").doc(widget.applicationId);
    final semRef = appRef.collection("semesterUpdates").doc(semesterNumber.toString());

    final batch = FirebaseFirestore.instance.batch();
    batch.update(semRef, {
      "status": "Rejected",
      "sponsorRemarks": remarksController.text.trim(),
      "reviewedAt": Timestamp.now(),
    });
    if (suspendScholarship) {
      batch.update(appRef, {"scholarshipStatus": "Suspended"});
    }
    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Semester $semesterNumber update rejected.")),
    );
  }

  Widget _buildSemesterUpdatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: Icons.history_edu_rounded, title: "Semester Updates"),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("applications")
              .doc(widget.applicationId)
              .collection("semesterUpdates")
              .orderBy("semesterNumber")
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const _Card(child: Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )));
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const _Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    "No semester updates submitted yet. These appear once the student completes a semester and uploads their marksheet.",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final doc in docs)
                  _SemesterUpdateTile(
                    data: doc.data() as Map<String, dynamic>,
                    onView: (url) => _openDocument(url),
                    onApprove: () => _approveSemesterUpdate((doc.data() as Map<String, dynamic>)["semesterNumber"] as int),
                    onReject: () => _rejectSemesterUpdate((doc.data() as Map<String, dynamic>)["semesterNumber"] as int),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Gradient header — matches the rest of the app's screens
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Text(
                  "Application Details",
                  style: AppTextStyles.title.copyWith(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            // Live document stream so verification/status changes reflect instantly —
            // falls back to the data passed in until the first snapshot arrives.
            child: StreamBuilder<DocumentSnapshot>(
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
                      _reveal(0, _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 27),
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
                      )),

                      const SizedBox(height: 22),
                      _reveal(1, Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(icon: Icons.person_outline_rounded, title: "Student Information"),
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
                        ],
                      )),

                      // Full student profile (category, income, year, roll number etc.)
                      // fetched live from users/{studentId} when the application
                      // references the student's uid.
                      if (data["studentId"] != null || data["uid"] != null) ...[
                        const SizedBox(height: 12),
                        _reveal(2, _StudentProfileCard(studentId: (data["studentId"] ?? data["uid"]).toString())),
                      ],

                      // Evaluation score — only shown once an academicScore exists
                      // (i.e. the student applied through the updated apply flow).
                      if (data["totalScore"] != null && data["academicScore"] != null) ...[
                        const SizedBox(height: 22),
                        _reveal(3, Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(icon: Icons.insights_rounded, title: "Evaluation Score"),
                            const SizedBox(height: 12),
                            _ScoreCard(data: data),
                          ],
                        )),
                      ],

                      if ((data["statementOfPurpose"] ?? "").toString().isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _reveal(4, Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(icon: Icons.edit_note_rounded, title: "Statement of Purpose"),
                            const SizedBox(height: 12),
                            _Card(
                              child: Text(
                                data["statementOfPurpose"].toString(),
                                style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                              ),
                            ),
                          ],
                        )),
                      ],

                      const SizedBox(height: 22),
                      _reveal(5, Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(icon: Icons.folder_copy_outlined, title: "Uploaded Documents"),
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
                        ],
                      )),

                      const SizedBox(height: 22),
                      _SectionHeader(icon: Icons.verified_user_outlined, title: "Document Verification"),
                      const SizedBox(height: 12),

                      _reveal(6, _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: documentsVerified,
                              onChanged: (value) => _toggleDocumentsVerified(value, data),
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
                      )),

                      // NEW — Semester Updates: only relevant once the application
                      // itself has been approved (semester renewal doesn't apply
                      // before that), so it's gated on status == "Approved".
                      if (status == "Approved") ...[
                        const SizedBox(height: 22),
                        _buildSemesterUpdatesSection(),
                      ],

                      const SizedBox(height: 22),
                      _reveal(7, Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(icon: Icons.info_outline_rounded, title: "Application Status"),
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
                                        style: AppTextStyles.subtitle
                                            .copyWith(color: statusColor, fontSize: 17, fontWeight: FontWeight.bold),
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
                        ],
                      )),

                      const SizedBox(height: 16),

                      _reveal(8, _Card(
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
                      )),

                      const SizedBox(height: 24),

                      _reveal(9, Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: status == "Approved"
                                        ? [AppColors.success.withOpacity(0.4), AppColors.success.withOpacity(0.4)]
                                        : [AppColors.success, AppColors.success.withOpacity(0.82)],
                                  ),
                                  boxShadow: status == "Approved"
                                      ? []
                                      : [
                                    BoxShadow(
                                      color: AppColors.success.withOpacity(0.30),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: status == "Approved" ? null : () => updateStatus("Approved", data),
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: const Text("Approve"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white.withOpacity(0.85),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: status == "Rejected" ? null : () => updateStatus("Rejected", data),
                                icon: Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                label: Text("Reject", style: TextStyle(color: AppColors.error)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.error, width: 1.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )),

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// Section header — small colored icon badge + title, used above each card
// ==============================
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ],
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
        border: Border.all(color: Colors.black.withOpacity(0.04)),
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
// A single semester update entry — shows marks + marksheet, and
// Approve/Reject buttons while it's still Pending.
// ==============================
class _SemesterUpdateTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(String url) onView;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _SemesterUpdateTile({
    required this.data,
    required this.onView,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = data["status"] ?? "Pending";
    final int semesterNumber = (data["semesterNumber"] is int) ? data["semesterNumber"] : 0;
    final marks = data["marksPercentage"];
    final String marksheetUrl = (data["marksheetUrl"] ?? "").toString();
    final String remarks = (data["sponsorRemarks"] ?? "").toString();

    final Color statusColor = status == "Approved"
        ? AppColors.success
        : status == "Rejected"
        ? AppColors.error
        : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == "Approved"
                    ? Icons.check_circle
                    : status == "Rejected"
                    ? Icons.cancel
                    : Icons.access_time_rounded,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Semester $semesterNumber — $marks%",
                  style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
              Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 10),
          if (marksheetUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () => onView(marksheetUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text("View Marksheet"),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            ),
          if (remarks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "Remarks: $remarks",
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
          if (status == "Pending") ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Approve"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Reject"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ==============================
// EVALUATION SCORE — Academic 50 + Financial need 30 + Documents 20
// ==============================
class _ScoreCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ScoreCard({required this.data});

  double _num(dynamic v) => (v is num) ? v.toDouble() : 0.0;

  @override
  Widget build(BuildContext context) {
    final total = _num(data["totalScore"]).clamp(0, 100);
    final academic = _num(data["academicScore"]);
    final income = _num(data["incomeScore"]);
    final documents = _num(data["documentsScore"]);

    final Color scoreColor = total >= 70
        ? AppColors.success
        : total >= 45
        ? AppColors.warning
        : AppColors.error;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor.withOpacity(0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    total.round().toString(),
                    style: AppTextStyles.title.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: scoreColor),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Out of 100", style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      "Academic marks + financial need + document verification",
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ScoreBar(label: "Academic Performance", value: academic, max: 50, color: AppColors.primary),
          const SizedBox(height: 10),
          _ScoreBar(label: "Financial Need", value: income, max: 30, color: AppColors.secondary),
          const SizedBox(height: 10),
          _ScoreBar(
            label: "Documents Verified",
            value: documents,
            max: 20,
            color: AppColors.success,
            note: documents == 0 ? "Not yet verified" : null,
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final String? note;
  const _ScoreBar({required this.label, required this.value, required this.max, required this.color, this.note});

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 12.5, color: AppColors.textPrimary)),
            Text(
              note ?? "${value.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}",
              style: AppTextStyles.subtitle.copyWith(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
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