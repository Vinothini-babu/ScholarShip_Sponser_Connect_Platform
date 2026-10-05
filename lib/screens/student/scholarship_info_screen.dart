import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../utils/eligibility_utils.dart';

/// Shows full details of a single scholarship.
///
/// detailsOnly = true  -> ONLY the scholarship details (used by the
///                        "Full details" button in the notification dialog)
/// detailsOnly = false -> details + eligible / not-eligible result
///                        (used when a student taps a non-eligible scholarship)
class ScholarshipInfoScreen extends StatelessWidget {
  final String scholarshipId;
  final bool detailsOnly;

  const ScholarshipInfoScreen({
    super.key,
    required this.scholarshipId,
    this.detailsOnly = false,
  });

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return "${date.day}/${date.month}/${date.year}";
    }
    return value?.toString() ?? "-";
  }

  /// Returns the first non-empty value found among the given keys.
  dynamic _pick(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      if (v is List && v.isEmpty) continue;
      return v;
    }
    return null;
  }

  /// Converts a String or List value into a readable text.
  String _asText(dynamic v) {
    if (v == null) return "";
    if (v is List) return v.map((e) => e.toString()).join(", ");
    return v.toString();
  }

  List<String> _asList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    final s = v.toString().trim();
    return s.isEmpty ? [] : [s];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Scholarship Details",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('scholarships')
            .doc(scholarshipId)
            .snapshots(),
        builder: (context, scholarshipSnapshot) {
          if (scholarshipSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!scholarshipSnapshot.hasData ||
              !scholarshipSnapshot.data!.exists) {
            return Center(
              child: Text(
                "Scholarship not found",
                style: AppTextStyles.subtitle,
              ),
            );
          }

          final scholarship = scholarshipSnapshot.data!.data() ?? {};

          // Details-only mode: no student/eligibility lookup at all
          if (detailsOnly) {
            return _buildBody(context, scholarship, null);
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: user == null
                ? null
                : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, studentSnapshot) {
              final studentData = studentSnapshot.data?.data() ?? {};
              final result = checkScholarshipEligibility(
                scholarship,
                studentData,
              );
              return _buildBody(context, scholarship, result.reasons);
            },
          );
        },
      ),
    );
  }

  /// [reasons] == null -> details only (no eligibility box)
  Widget _buildBody(
      BuildContext context,
      Map<String, dynamic> scholarship,
      List<String>? reasons,
      ) {
    final description = _asText(scholarship["description"]);
    final benefits = _asText(scholarship["benefits"]);
    final selectionProcess = _asText(scholarship["selectionProcess"]);
    final eligibility = _asText(scholarship["eligibility"]);

    final courses = _asList(scholarship["eligibleCourse"]);
    final categories = _asList(scholarship["eligibleCategory"]);
    final documents = _asList(scholarship["requiredDocuments"]);

    final minPercent = _pick(scholarship, [
      "minimumPercentage",
      "minPercentage",
      "minimumMarks",
    ]);
    final maxIncome = _pick(scholarship, [
      "maximumIncome",
      "maximumAnnualIncome",
      "maxIncome",
    ]);

    return TweenAnimationBuilder<double>(
      key: ValueKey(scholarshipId),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Header ----------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: .78),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .28),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        scholarship["title"]?.toString() ?? "Scholarship",
                        style: AppTextStyles.title.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "By ${scholarship["sponsorName"]?.toString() ?? "Sponsor"}",
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white.withValues(alpha: .9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ---------- Amount / Deadline ----------
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.currency_rupee,
                        label: "Amount",
                        value: scholarship["amount"]?.toString() ?? "-",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.calendar_today,
                        label: "Last date",
                        value: _formatDate(scholarship["lastDate"]),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ---------- About ----------
                if (description.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.info_outline_rounded,
                    text: "About this scholarship",
                  ),
                  const SizedBox(height: 10),
                  _TextCard(text: description),
                  const SizedBox(height: 22),
                ],

                // ---------- Benefits ----------
                if (benefits.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.card_giftcard_rounded,
                    text: "Benefits",
                  ),
                  const SizedBox(height: 10),
                  _TextCard(text: benefits),
                  const SizedBox(height: 22),
                ],

                // ---------- Eligibility ----------
                _SectionLabel(
                  icon: Icons.checklist_rounded,
                  text: "Eligibility requirements",
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: .2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (minPercent != null)
                        _KeyValueRow(
                          label: "Minimum marks",
                          value: "${minPercent.toString()}%",
                        ),
                      if (maxIncome != null)
                        _KeyValueRow(
                          label: "Max annual income",
                          value: "₹${maxIncome.toString()}",
                        ),
                      if (courses.isNotEmpty)
                        _KeyValueRow(
                          label: "Eligible courses",
                          value: courses.join(", "),
                        ),
                      if (categories.isNotEmpty)
                        _KeyValueRow(
                          label: "Eligible category",
                          value: categories.join(", "),
                        ),
                      if (eligibility.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            eligibility,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      if (minPercent == null &&
                          maxIncome == null &&
                          courses.isEmpty &&
                          categories.isEmpty &&
                          eligibility.isEmpty)
                        Text(
                          "Open to all students.",
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ---------- Selection process ----------
                if (selectionProcess.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.how_to_reg_rounded,
                    text: "Selection process",
                  ),
                  const SizedBox(height: 10),
                  _TextCard(text: selectionProcess),
                  const SizedBox(height: 22),
                ],

                // ---------- Required documents ----------
                if (documents.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.description_outlined,
                    text: "Documents to upload",
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: documents
                        .map(
                          (d) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              d,
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .toList(),
                  ),
                  const SizedBox(height: 22),
                ],

                // ---------- Eligibility result (NOT in details-only mode) ----------
                if (reasons != null) ...[
                  if (reasons.isEmpty)
                    const _EligibleBox()
                  else
                    _NotEligibleBox(reasons: reasons),
                ],

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final String text;

  const _TextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: AppColors.textSecondary.withValues(alpha: .10)),
      ),
      child: Text(
        text,
        style: AppTextStyles.subtitle.copyWith(
          color: AppColors.textPrimary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EligibleBox extends StatelessWidget {
  const _EligibleBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.check_rounded, size: 16, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You're eligible for this scholarship",
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.green.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotEligibleBox extends StatelessWidget {
  final List<String> reasons;

  const _NotEligibleBox({required this.reasons});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: .15),
                  shape: BoxShape.circle,
                ),
                child:
                Icon(Icons.close_rounded, size: 16, color: AppColors.error),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "You're not eligible for this scholarship",
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...reasons.map(
                (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 5, color: AppColors.error),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.subtitle.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: AppColors.textSecondary.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: AppTextStyles.subtitle
                  .copyWith(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(value,
              style: AppTextStyles.subtitle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}