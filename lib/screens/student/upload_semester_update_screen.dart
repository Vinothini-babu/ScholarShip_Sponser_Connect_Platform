import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/storage_service.dart';

/// Lets a student, after completing a semester, upload that semester's
/// marksheet + marks percentage so the sponsor can review it and continue
/// the scholarship into the next semester.
///
/// Firestore layout (new):
///   applications/{applicationId}
///     currentSemester   -> int, defaults to 1 (the semester currently in
///                           progress / most recently completed but not
///                           yet submitted)
///     scholarshipStatus -> "Active" | "Suspended" | "Completed"
///     semesterUpdates/{semesterNumber}   <- subcollection, one doc per
///       semesterNumber   -> int
///       marksPercentage  -> num
///       marksheetUrl     -> String (Firebase Storage download URL)
///       submittedAt      -> Timestamp
///       status           -> "Pending" | "Approved" | "Rejected"
///       sponsorRemarks   -> String
///       reviewedAt       -> Timestamp?
class UploadSemesterUpdateScreen extends StatefulWidget {
  final String applicationId;

  const UploadSemesterUpdateScreen({super.key, required this.applicationId});

  @override
  State<UploadSemesterUpdateScreen> createState() => _UploadSemesterUpdateScreenState();
}

class _UploadSemesterUpdateScreenState extends State<UploadSemesterUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _marksController = TextEditingController();

  PlatformFile? _pickedFile;
  bool _isSubmitting = false;
  bool _isUploading = false;

  // Same validation vocabulary used elsewhere in the app
  // (upload_documents_screen.dart / scholarship_application_screen.dart) —
  // kept local here so this screen has no new dependency, but should stay
  // in sync if those lists change.
  static const List<String> _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
  static const int _minFileSizeBytes = 10 * 1024; // 10 KB
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  static const List<String> _suspiciousNameKeywords = [
    'test', 'sample', 'dummy', 'fake', 'temp', 'untitled', 'new_document',
  ];

  static const List<String> _screenshotNameKeywords = [
    'screenshot', 'screen_shot', 'screenrecording', 'img_wa', 'snip', 'capture',
  ];

  // Common device/monitor resolutions — if a picked image matches one of
  // these exactly, it's very likely a screenshot even if renamed.
  static const List<List<int>> _commonScreenResolutions = [
    [1080, 1920], [1170, 2532], [1080, 2400], [1440, 3200],
    [1920, 1080], [1366, 768], [2560, 1440], [1280, 720], [1600, 900],
  ];

  @override
  void dispose() {
    _marksController.dispose();
    super.dispose();
  }

  Future<void> _pickMarksheet() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (file == null) return;

    final error = await _validateFile(file);
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _pickedFile = file);
  }

  Future<String?> _validateFile(PlatformFile file) async {
    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';

    if (!_allowedExtensions.contains(ext)) {
      return "Only PDF, JPG or PNG files are accepted for the marksheet.";
    }

    // PlatformFile.size was removed in file_picker v13 — same fix as
    // upload_documents_screen.dart's _validateDocument.
    final int size = file.lengthSync() ?? await file.length() ?? 0;

    if (size < _minFileSizeBytes) {
      return "This file looks too small to be a real marksheet. Please upload the original document.";
    }
    if (size > _maxFileSizeBytes) {
      return "File is too large (max 10 MB). Please upload a smaller scan or photo.";
    }

    if (_suspiciousNameKeywords.any((k) => name.contains(k))) {
      return "This file name looks like a placeholder, not a real marksheet. Please upload your actual marksheet.";
    }
    if (_screenshotNameKeywords.any((k) => name.contains(k))) {
      return "Screenshots aren't accepted. Please upload the original marksheet file (PDF or scanned image).";
    }

    if ((ext == 'jpg' || ext == 'jpeg' || ext == 'png') && file.path != null) {
      final isScreenshotDims = await _looksLikeScreenshotByDimensions(file.path!);
      if (isScreenshotDims) {
        return "This image matches a common screen resolution and looks like a screenshot. Please upload the original marksheet file.";
      }
    }

    return null;
  }

  Future<bool> _looksLikeScreenshotByDimensions(String path) async {
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      return _commonScreenResolutions.any((res) =>
      (res[0] == w && res[1] == h) || (res[0] == h && res[1] == w));
    } catch (_) {
      // If we can't decode it, don't block the student on that basis alone —
      // the extension/name/size checks above already ran.
      return false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(int semesterNumber) async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      _showError("Please upload your marksheet before submitting.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final marks = double.parse(_marksController.text.trim());

      final localPath = _pickedFile!.path;
      if (localPath == null || localPath.isEmpty) {
        throw Exception("Unable to read the selected file");
      }

      final ext = _pickedFile!.name.contains('.') ? _pickedFile!.name.split('.').last : 'pdf';

      setState(() => _isUploading = true);
      // Upload to Firebase Storage first — the sponsor's "View" button
      // opens this URL, so a local device path here would leave them
      // with nothing openable.
      final marksheetUrl = await StorageService.uploadFile(
        file: File(localPath),
        folder: "applications/${widget.applicationId}/semesterUpdates",
        fileName: StorageService.buildFileName("semester_$semesterNumber", ext),
      );
      setState(() => _isUploading = false);

      await FirebaseFirestore.instance
          .collection("applications")
          .doc(widget.applicationId)
          .collection("semesterUpdates")
          .doc(semesterNumber.toString())
          .set({
        "semesterNumber": semesterNumber,
        "marksPercentage": marks,
        "marksheetUrl": marksheetUrl,
        "submittedAt": Timestamp.now(),
        "status": "Pending",
        "sponsorRemarks": "",
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semester marks submitted for review.")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showError("Something went wrong while submitting. Please try again.");
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text("Semester Update"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("applications").doc(widget.applicationId).snapshots(),
        builder: (context, appSnap) {
          if (!appSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final appData = (appSnap.data!.data() as Map<String, dynamic>?) ?? {};
          final int currentSemester = (appData["currentSemester"] is int) ? appData["currentSemester"] : 1;
          final String scholarshipStatus = appData["scholarshipStatus"] ?? "Active";

          if (scholarshipStatus == "Suspended") {
            return _StatusMessage(
              icon: Icons.pause_circle_outline_rounded,
              color: AppColors.warning,
              title: "Scholarship Suspended",
              message: "Your scholarship is currently suspended. Please contact the sponsor for details.",
            );
          }
          if (scholarshipStatus == "Completed") {
            return _StatusMessage(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              title: "Scholarship Completed",
              message: "There are no further semester updates required.",
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("applications")
                .doc(widget.applicationId)
                .collection("semesterUpdates")
                .orderBy("semesterNumber")
                .snapshots(),
            builder: (context, historySnap) {
              final history = historySnap.data?.docs ?? [];

              final currentDoc = history.where((d) => d.id == currentSemester.toString()).toList();
              final bool hasPendingCurrent = currentDoc.isNotEmpty &&
                  (currentDoc.first.data() as Map<String, dynamic>)["status"] == "Pending";

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (history.isNotEmpty) ...[
                      Text("Semester History", style: AppTextStyles.title.copyWith(fontSize: 17)),
                      const SizedBox(height: 12),
                      for (final doc in history) _SemesterHistoryTile(data: doc.data() as Map<String, dynamic>),
                      const SizedBox(height: 24),
                    ],
                    if (hasPendingCurrent)
                      _StatusMessage(
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                        title: "Waiting for Review",
                        message: "Your semester $currentSemester marks are submitted and awaiting sponsor review.",
                      )
                    else
                      _buildForm(context, currentSemester),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, int semesterNumber) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Upload Semester $semesterNumber Marks", style: AppTextStyles.title.copyWith(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            "Completed semester $semesterNumber? Upload your marksheet and marks percentage to continue your scholarship.",
            style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _marksController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Marks Percentage",
              hintText: "e.g. 78.5",
              suffixText: "%",
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Enter your marks percentage";
              final parsed = double.tryParse(value.trim());
              if (parsed == null) return "Enter a valid number";
              if (parsed < 0 || parsed > 100) return "Enter a value between 0 and 100";
              return null;
            },
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickMarksheet,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _pickedFile != null ? AppColors.success : AppColors.textSecondary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pickedFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                    color: _pickedFile != null ? AppColors.success : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _pickedFile?.name ?? "Upload Marksheet (PDF, JPG or PNG)",
                      style: AppTextStyles.subtitle.copyWith(fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _submit(semesterNumber),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(_isUploading ? "Uploading marksheet..." : "Submitting..."),
                ],
              )
                  : const Text("Submit for Review"),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterHistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SemesterHistoryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data["status"] ?? "Pending";
    final Color color = status == "Approved"
        ? AppColors.success
        : status == "Rejected"
        ? AppColors.error
        : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            status == "Approved"
                ? Icons.check_circle
                : status == "Rejected"
                ? Icons.cancel
                : Icons.access_time_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Semester ${data["semesterNumber"]} — ${data["marksPercentage"]}%",
                  style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                if ((data["sponsorRemarks"] ?? "").toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      data["sponsorRemarks"],
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  const _StatusMessage({required this.icon, required this.color, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text(message, style: AppTextStyles.subtitle.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}