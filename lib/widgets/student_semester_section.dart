import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import 'semester_release_timeline.dart';

/// Student-side "Semester Update" card for an APPROVED application.
///
/// Shows: current semester (N of T), scholarship release timeline
/// (Locked / Released), and the right action for the current semester:
///   - no submission yet  -> "Upload Semester N Marks" button
///   - Pending            -> "Waiting for sponsor review"
///   - Rejected           -> sponsor remarks + "Re-upload" button
///   - Suspended          -> message (no upload)
///   - Completed          -> congratulations message
///
/// Usage (inside the student's application screen / card):
///   StudentSemesterSection(
///     applicationId: id,
///     onUpload: () => Navigator.push(context, MaterialPageRoute(
///       builder: (_) => UploadSemesterUpdateScreen(applicationId: id))),
///   )
class StudentSemesterSection extends StatelessWidget {
  final String applicationId;
  final VoidCallback onUpload;

  const StudentSemesterSection({
    super.key,
    required this.applicationId,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final appRef =
    FirebaseFirestore.instance.collection("applications").doc(applicationId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: appRef.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        if (d == null) return const SizedBox.shrink();

        // Semester updates only exist once the application is approved
        if ((d["status"] ?? "").toString() != "Approved") {
          return const SizedBox.shrink();
        }

        final String scholarshipStatus =
        (d["scholarshipStatus"] ?? "Active").toString();
        final int currentSemester =
        d["currentSemester"] is int ? d["currentSemester"] as int : 1;
        final int? total =
        d["totalSemesters"] is int ? d["totalSemesters"] as int : null;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_edu_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Semester Update",
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (scholarshipStatus == "Active")
                    Text(
                      total == null
                          ? "Semester $currentSemester"
                          : "Semester $currentSemester of $total",
                      style: AppTextStyles.subtitle.copyWith(
                          fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (scholarshipStatus == "Completed")
                _banner(
                  icon: Icons.verified_rounded,
                  color: AppColors.success,
                  text: total != null
                      ? "Scholarship completed — all $total semesters done. Congratulations! 🎓"
                      : "Scholarship completed. Congratulations! 🎓",
                )
              else if (scholarshipStatus == "Suspended")
                _banner(
                  icon: Icons.pause_circle_outline_rounded,
                  color: AppColors.warning,
                  text:
                  "Your scholarship is suspended by the sponsor. You can submit marks again once it is reactivated. Please contact your sponsor.",
                )
              else
                _currentSemesterAction(appRef, currentSemester),

              const SizedBox(height: 14),
              SemesterReleaseTimeline(
                applicationId: applicationId,
                currentSemester: currentSemester,
                totalSemesters: total,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _currentSemesterAction(
      DocumentReference<Map<String, dynamic>> appRef, int semester) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: appRef
          .collection("semesterUpdates")
          .doc(semester.toString())
          .snapshots(),
      builder: (context, snap) {
        final u = snap.data?.data();
        final String status = (u?["status"] ?? "").toString();

        if (status == "Pending") {
          return _banner(
            icon: Icons.hourglass_top_rounded,
            color: AppColors.warning,
            text:
            "Semester $semester marks submitted — waiting for the sponsor's review.",
          );
        }

        final bool rejected = status == "Rejected";
        final String remarks = (u?["sponsorRemarks"] ?? "").toString().trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rejected)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _banner(
                  icon: Icons.error_outline_rounded,
                  color: AppColors.error,
                  text: remarks.isEmpty
                      ? "Your semester $semester update was rejected. Please upload again."
                      : "Your semester $semester update was rejected: $remarks",
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  "Completed semester $semester? Upload your marks and marksheet. The scholarship for the next semester is released after the sponsor approves it.",
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(rejected
                    ? "Re-upload Semester $semester Marks"
                    : "Upload Semester $semester Marks"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _banner(
      {required IconData icon, required Color color, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}