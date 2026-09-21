import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/application_model.dart';
import '../../../services/application_service.dart';

/// Dedicated "fill in your application" screen. Reached by tapping
/// "Apply Now" on a scholarship (from the Eligible Scholarships list, or
/// any other screen that links here) instead of filling everything out
/// inline inside a scrollable card.
class ScholarshipApplicationScreen extends StatefulWidget {
  final String scholarshipId;
  final String title;
  final String amount;
  final String lastDate;
  final String eligibility;

  /// The exact documents this scholarship's sponsor marked as required —
  /// only these are shown here, not a fixed one-size-fits-all list.
  final List<String> requiredDocuments;

  const ScholarshipApplicationScreen({
    super.key,
    required this.scholarshipId,
    required this.title,
    required this.amount,
    required this.lastDate,
    required this.eligibility,
    required this.requiredDocuments,
  });

  @override
  State<ScholarshipApplicationScreen> createState() => _ScholarshipApplicationScreenState();
}

class _ScholarshipApplicationScreenState extends State<ScholarshipApplicationScreen> {
  final ApplicationService _applicationService = ApplicationService();
  final TextEditingController _statementController = TextEditingController();

  // documentName -> local file path picked for it
  final Map<String, String> _documents = {};

  bool _isPickingDocument = false;
  bool _isApplying = false;

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  // =============================================================
  // VALIDATION RULES (kept in sync with upload_documents_screen.dart)
  // =============================================================

  static const int _minFileSizeBytes = 20 * 1024; // 20 KB
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  static const List<String> _suspiciousNameKeywords = [
    "fake",
    "dummy",
    "sample",
    "test",
    "placeholder",
  ];

  static const List<String> _screenshotNameKeywords = [
    "screenshot",
    "screen_shot",
    "screen-shot",
    "screen shot",
    "screenrecording",
    "screen_recording",
    "screen-recording",
    "img_wa",
    "img-wa",
    "snip",
    "capture",
  ];

  /// Common device/monitor resolutions (both orientations). An image whose
  /// pixel dimensions land exactly on one of these is very likely a raw
  /// screen capture rather than a scanned/photographed document — this
  /// catches screenshots that were renamed to dodge the filename check.
  static const List<List<int>> _screenResolutions = [
    [1920, 1080], [1080, 1920],
    [1366, 768], [768, 1366],
    [1536, 864], [864, 1536],
    [1440, 900], [900, 1440],
    [1280, 720], [720, 1280],
    [1600, 900], [900, 1600],
    [2560, 1440], [1440, 2560],
    [3840, 2160], [2160, 3840],
    [412, 915], [915, 412],
    [393, 852], [852, 393],
    [1080, 2400], [2400, 1080],
    [1080, 2340], [2340, 1080],
    [360, 800], [800, 360],
  ];

  Future<bool> _looksLikeScreenCaptureDimensions(String path, String extension) async {
    if (extension == "pdf") return false; // dimension check only applies to raster images
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      return _screenResolutions.any((res) => res[0] == w && res[1] == h);
    } catch (_) {
      // If we can't decode it, don't block on this check alone.
      return false;
    }
  }

  /// Returns null if the file passes validation, otherwise an error
  /// message explaining why it was rejected.
  Future<String?> _validateDocument(PlatformFile file, String documentName) async {
    final extension = (file.extension ?? "").toLowerCase();

    if (!["pdf", "jpg", "jpeg", "png"].contains(extension)) {
      return "Unsupported file type. Please upload a PDF or image.";
    }

    final int fileSize = file.lengthSync() ?? await file.length() ?? 0;

    if (fileSize < _minFileSizeBytes) {
      return "This file looks empty or invalid. Please upload the original $documentName.";
    }

    if (fileSize > _maxFileSizeBytes) {
      return "File is too large (max 5 MB). Please upload a valid $documentName.";
    }

    final lowerName = file.name.toLowerCase();

    for (final keyword in _screenshotNameKeywords) {
      if (lowerName.contains(keyword)) {
        return "Screenshots are not accepted. Please upload the original scanned copy "
            "or photo of your $documentName (PDF, JPG, or PNG) — not a screenshot.";
      }
    }

    for (final keyword in _suspiciousNameKeywords) {
      if (lowerName.contains(keyword)) {
        return "This doesn't look like a genuine document. Please upload your original $documentName.";
      }
    }

    if (file.path != null) {
      final isScreenCapture = await _looksLikeScreenCaptureDimensions(file.path!, extension);
      if (isScreenCapture) {
        return "This image matches a screen capture resolution and looks like a screenshot. "
            "Please upload the original scanned copy or photo of your $documentName instead.";
      }
    }

    return null;
  }

  Future<void> _pickDocument(String documentName) async {
    if (_isPickingDocument) return;

    setState(() => _isPickingDocument = true);

    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ["pdf", "jpg", "jpeg", "png"],
      );

      if (file == null) return;

      if (file.path == null || file.path!.isEmpty) {
        throw Exception("Unable to get selected file path");
      }

      final validationError = await _validateDocument(file, documentName);

      if (validationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(validationError)),
              ],
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      setState(() => _documents[documentName] = file.path!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$documentName selected")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to select document: $e")),
      );
    } finally {
      if (mounted) setState(() => _isPickingDocument = false);
    }
  }

  // =============================================================
  // SUBMIT APPLICATION
  // =============================================================

  Future<void> _submitApplication() async {
    if (_isApplying) return;

    final missing = widget.requiredDocuments.where((d) => !_documents.containsKey(d)).toList();

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text("Please upload: ${missing.join(', ')}"),
        ),
      );
      return;
    }

    if (_statementController.text.trim().length < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: const Text("Please write at least a couple of sentences on why you need this scholarship."),
        ),
      );
      return;
    }

    setState(() => _isApplying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Please login again");

      final firestore = FirebaseFirestore.instance;

      final studentSnapshot = await firestore.collection("users").doc(user.uid).get();
      if (!studentSnapshot.exists) throw Exception("Student profile not found");

      final studentData = studentSnapshot.data()!;
      final studentName = studentData["name"]?.toString().trim() ?? "";
      final studentCollege = studentData["college"]?.toString().trim() ?? "";
      final studentEmail = studentData["email"]?.toString().trim() ?? user.email ?? "";

      if (studentName.isEmpty) throw Exception("Student name is empty in profile");
      if (studentCollege.isEmpty) throw Exception("Student college is empty in profile");

      final scholarshipSnapshot =
      await firestore.collection("scholarships").doc(widget.scholarshipId).get();
      if (!scholarshipSnapshot.exists) throw Exception("Scholarship not found");

      final scholarshipData = scholarshipSnapshot.data()!;
      final sponsorId = scholarshipData["sponsorId"]?.toString().trim() ?? "";

      if (sponsorId.isEmpty) {
        throw Exception("Sponsor information is missing for this scholarship");
      }

      final application = ApplicationModel(
        id: "",
        studentId: user.uid,
        studentName: studentName,
        studentEmail: studentEmail,
        studentCollege: studentCollege,
        sponsorId: sponsorId,
        scholarshipId: widget.scholarshipId,
        scholarshipTitle: widget.title,
        amount: widget.amount,
        status: "Pending",
        appliedAt: Timestamp.now(),
        // Keyed by the actual document name (e.g. "Income Certificate")
        // rather than a fixed internal key, matching what the sponsor's
        // review screen expects.
        documents: _documents,
      );

      final result = await _applicationService.applyScholarship(application);
      final success = result == "Success";

      // ApplicationModel doesn't carry a statement-of-purpose field, so it's
      // attached with a follow-up update once the application exists —
      // studentId + scholarshipId is unique per student (enforced by the
      // "Already Applied" check above), so this always finds the right doc.
      if (success && _statementController.text.trim().isNotEmpty) {
        final createdQuery = await firestore
            .collection("applications")
            .where("studentId", isEqualTo: user.uid)
            .where("scholarshipId", isEqualTo: widget.scholarshipId)
            .limit(1)
            .get();

        if (createdQuery.docs.isNotEmpty) {
          await createdQuery.docs.first.reference.update({
            "statementOfPurpose": _statementController.text.trim(),
          });
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "Application submitted successfully"
                : result == "Already Applied"
                ? "You already applied for this scholarship"
                : "Application failed: $result",
          ),
        ),
      );

      if (success) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to apply: $e")),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Apply for Scholarship",
          style: AppTextStyles.title.copyWith(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scholarship summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5)),
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
                          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: AppTextStyles.subtitle.copyWith(
                              fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.currency_rupee_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(widget.amount,
                          style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(width: 18),
                      Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text("Deadline: ${widget.lastDate}",
                          style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text("Your Details", style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              "This is what the sponsor will see, pulled from your profile.",
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            const _YourDetailsCard(),

            const SizedBox(height: 20),

            Text("Required Documents", style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              "Upload the exact ${widget.requiredDocuments.length} document(s) this sponsor requires.",
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            ...widget.requiredDocuments.map((documentName) {
              final selectedPath = _documents[documentName];
              final bool selected = selectedPath != null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? AppColors.success.withOpacity(0.35) : AppColors.textSecondary.withOpacity(0.12),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.success.withOpacity(0.12) : AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        selected ? Icons.check_circle_rounded : Icons.description_outlined,
                        color: selected ? AppColors.success : AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(documentName,
                              style: AppTextStyles.subtitle.copyWith(
                                  fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                            selected ? selectedPath.split(Platform.pathSeparator).last : "No file selected",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitle.copyWith(
                                fontSize: 12, color: selected ? AppColors.success : AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isPickingDocument ? null : () => _pickDocument(documentName),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(selected ? "Change" : "Upload",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            Text("Statement of Purpose",
                style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              "Briefly tell the sponsor why you need this scholarship and how it will help you.",
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _statementController,
                maxLines: 5,
                maxLength: 600,
                style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                  "e.g. I come from a farming family and this scholarship would let me continue my "
                      "engineering degree without dropping out to work...",
                  hintStyle: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.6),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.82)]),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.30), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isApplying ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isApplying
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text("Submit Application",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ==============================
// YOUR DETAILS — read-only review of the student's own profile
// ==============================
class _YourDetailsCard extends StatelessWidget {
  const _YourDetailsCard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection("users").doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
            child: const Text("Unable to load your profile details."),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final rows = <Widget>[];

        void addRow(IconData icon, String label, dynamic value) {
          if (value == null || value.toString().trim().isEmpty) return;
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 14));
          rows.add(_DetailRow(icon: icon, label: label, value: value.toString()));
        }

        addRow(Icons.person_outline_rounded, "Name", data["name"]);
        addRow(Icons.email_outlined, "Email", data["email"]);
        addRow(Icons.phone_outlined, "Mobile", data["mobile"]);
        addRow(Icons.account_balance_outlined, "College", data["college"]);
        addRow(Icons.menu_book_outlined, "Course", data["course"]);
        addRow(Icons.timeline_outlined, "Year of Study", data["yearOfStudy"]);
        addRow(Icons.badge_outlined, "Roll / Register Number", data["rollNumber"]);
        addRow(Icons.groups_outlined, "Category", data["category"]);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: rows.isEmpty
              ? const Text("Complete your profile to have your details shown here.")
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
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