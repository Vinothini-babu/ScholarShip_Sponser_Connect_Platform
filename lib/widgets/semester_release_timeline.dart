import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

/// Shows, semester by semester, whether the scholarship is
/// Locked or Released for an application.
///
/// Firestore: applications/{applicationId}/scholarshipReleases/{semesterNumber}
///   semesterNumber -> int
///   amount         -> String (copied from the application)
///   status         -> "Locked" | "Released"
///   releasedAt     -> Timestamp (when Released)
///   releasedBy     -> String (sponsor uid)
///
/// Older applications (approved before this feature) have no release docs,
/// so we fall back to: semester <= currentSemester  => Released, else Locked.
class SemesterReleaseTimeline extends StatelessWidget {
  final String applicationId;
  final int? totalSemesters;
  final int currentSemester;

  const SemesterReleaseTimeline({
    super.key,
    required this.applicationId,
    required this.currentSemester,
    this.totalSemesters,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("applications")
          .doc(applicationId)
          .collection("scholarshipReleases")
          .snapshots(),
      builder: (context, snap) {
        final Map<int, Map<String, dynamic>> docs = {};
        for (final d in snap.data?.docs ?? const []) {
          final n = int.tryParse(d.id);
          if (n != null) docs[n] = d.data();
        }

        int total = totalSemesters ?? currentSemester;
        if (docs.isNotEmpty) {
          total = math.max(total, docs.keys.reduce(math.max));
        }
        if (total < 1) total = 1;

        String statusOf(int n) {
          final s = docs[n]?["status"];
          if (s is String && s.isNotEmpty) return s;
          return n <= currentSemester ? "Released" : "Locked";
        }

        final releasedCount =
            List.generate(total, (i) => i + 1).where((n) => statusOf(n) == "Released").length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Scholarship Release",
                      style: AppTextStyles.subtitle
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  Text(
                    "$releasedCount of $total released",
                    style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int n = 1; n <= total; n++)
                    _chip(n, statusOf(n) == "Released"),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(int n, bool released) {
    final Color c = released ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(released ? Icons.check_circle_rounded : Icons.lock_rounded,
              size: 14, color: c),
          const SizedBox(width: 5),
          Text(
            "Sem $n · ${released ? "Released" : "Locked"}",
            style: TextStyle(
                color: c, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}