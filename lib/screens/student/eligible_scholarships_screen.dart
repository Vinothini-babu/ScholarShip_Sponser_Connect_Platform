import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/scholarship_model.dart';
import '../../../services/saved_scholarship_service.dart';

class EligibleScholarshipsScreen extends StatefulWidget {
  const EligibleScholarshipsScreen({super.key});

  @override
  State<EligibleScholarshipsScreen> createState() =>
      _EligibleScholarshipsScreenState();
}

class _EligibleScholarshipsScreenState
    extends State<EligibleScholarshipsScreen> {

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final SavedScholarshipService _savedService =
  SavedScholarshipService();

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().trim(),
    ) ??
        0;
  }

  bool _matches(
      Map<String, dynamic> scholarship,
      Map<String, dynamic> student,
      ) {
    final studentCourse =
    (student["course"] ?? "")
        .toString()
        .trim()
        .toLowerCase();

    final studentCategory =
    (student["category"] ?? "")
        .toString()
        .trim()
        .toLowerCase();

    final studentPercentage =
    _toDouble(student["percentage"]);

    final studentIncome =
    _toDouble(student["annualIncome"]);

    final requiredCourse =
    (scholarship["eligibleCourse"] ?? "")
        .toString()
        .trim()
        .toLowerCase();

    final requiredCategory =
    (scholarship["eligibleCategory"] ?? "")
        .toString()
        .trim()
        .toLowerCase();

    final minimumPercentage =
    _toDouble(
      scholarship["minimumPercentage"],
    );

    final maximumIncome =
    _toDouble(
      scholarship["maximumAnnualIncome"],
    );

    final courseEligible =
        requiredCourse.isEmpty ||
            requiredCourse == "all" ||
            studentCourse == requiredCourse;

    final categoryEligible =
        requiredCategory.isEmpty ||
            requiredCategory == "all" ||
            studentCategory == requiredCategory;

    final percentageEligible =
        studentPercentage >= minimumPercentage;

    final incomeEligible =
        studentIncome <= maximumIncome;

    return courseEligible &&
        categoryEligible &&
        percentageEligible &&
        incomeEligible;
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Please login again"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,

        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),

        title: Text(
          "Eligible Scholarships",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection("users")
            .doc("student")
            .collection(user.uid)
            .doc("profile")
            .snapshots(),

        builder: (context, profileSnapshot) {

          if (profileSnapshot.connectionState ==
              ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (profileSnapshot.hasError) {
            return Center(
              child: Text(
                "Unable to load profile",
                style: AppTextStyles.subtitle,
              ),
            );
          }

          if (!profileSnapshot.hasData ||
              !profileSnapshot.data!.exists) {
            return Center(
              child: Text(
                "Please complete your profile first.",
                style: AppTextStyles.subtitle,
              ),
            );
          }

          final studentData =
              profileSnapshot.data!.data() ?? {};

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection("scholarships")
                .where(
              "status",
              isEqualTo: "Active",
            )
                .snapshots(),

            builder: (context, scholarshipSnapshot) {

              if (scholarshipSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                );
              }

              if (scholarshipSnapshot.hasError) {
                return Center(
                  child: Text(
                    "Unable to load scholarships",
                    style: AppTextStyles.subtitle,
                  ),
                );
              }

              if (!scholarshipSnapshot.hasData ||
                  scholarshipSnapshot.data!.docs.isEmpty) {
                return _emptyState(
                  "No Scholarships Available",
                );
              }

              final eligibleScholarships =
              scholarshipSnapshot.data!.docs
                  .where(
                    (doc) => _matches(
                  doc.data(),
                  studentData,
                ),
              )
                  .toList();

              if (eligibleScholarships.isEmpty) {
                return _emptyState(
                  "No Eligible Scholarships",
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: eligibleScholarships.length,

                itemBuilder: (context, index) {

                  final doc =
                  eligibleScholarships[index];

                  final data = doc.data();

                  return _EligibleScholarshipCard(
                    scholarshipId: doc.id,
                    title:
                    data["title"]?.toString() ??
                        "Scholarship",
                    amount:
                    data["amount"]?.toString() ??
                        "",
                    lastDate:
                    _formatDate(
                      data["lastDate"],
                    ),
                    eligibility:
                    data["eligibility"]?.toString() ??
                        "",
                    savedService: _savedService,
                    studentId: user.uid,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Icon(
              Icons.workspace_premium_outlined,
              size: 70,
              color: AppColors.secondary,
            ),

            const SizedBox(height: 16),

            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(
                fontSize: 19,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Scholarships matching your profile will appear here.",
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      return "${date.day.toString().padLeft(2, '0')}/"
          "${date.month.toString().padLeft(2, '0')}/"
          "${date.year}";
    }

    return value?.toString() ?? "";
  }
}
class _EligibleScholarshipCard extends StatefulWidget {
  final String scholarshipId;
  final String title;
  final String amount;
  final String lastDate;
  final String eligibility;
  final SavedScholarshipService savedService;
  final String studentId;

  const _EligibleScholarshipCard({
    required this.scholarshipId,
    required this.title,
    required this.amount,
    required this.lastDate,
    required this.eligibility,
    required this.savedService,
    required this.studentId,
  });

  @override
  State<_EligibleScholarshipCard> createState() =>
      _EligibleScholarshipCardState();
}

class _EligibleScholarshipCardState
    extends State<_EligibleScholarshipCard> {

  bool _isSaving = false;

  Future<void> _toggleSave() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final saved = await widget.savedService.isSaved(
        studentId: widget.studentId,
        scholarshipId: widget.scholarshipId,
      ).first;

      if (saved) {
        await widget.savedService.removeSavedScholarship(
          studentId: widget.studentId,
          scholarshipId: widget.scholarshipId,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Scholarship removed from saved",
            ),
          ),
        );
      } else {
        await widget.savedService.saveScholarship(
          studentId: widget.studentId,
          scholarshipId: widget.scholarshipId,
          title: widget.title,
          amount: widget.amount,
          lastDate: widget.lastDate,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "❤️ Scholarship saved",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to save scholarship: $e",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.savedService.isSaved(
        studentId: widget.studentId,
        scholarshipId: widget.scholarshipId,
      ),

      builder: (context, snapshot) {

        final isSaved = snapshot.data ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: AppColors.secondary
                  .withOpacity(0.15),
            ),

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

              // =========================================
              // HEADER
              // =========================================

              Row(
                children: [

                  Container(
                    width: 50,
                    height: 50,

                    decoration: BoxDecoration(
                      color: AppColors.secondary
                          .withOpacity(0.12),
                      borderRadius:
                      BorderRadius.circular(14),
                    ),

                    child: Icon(
                      Icons.school_rounded,
                      color: AppColors.primary,
                      size: 25,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      AppTextStyles.title.copyWith(
                        fontSize: 16,
                        color:
                        AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // =====================================
                  // SAVE BUTTON
                  // =====================================

                  IconButton(
                    onPressed:
                    _isSaving
                        ? null
                        : _toggleSave,

                    icon: _isSaving
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                        AppColors.primary,
                      ),
                    )
                        : Icon(
                      isSaved
                          ? Icons.favorite_rounded
                          : Icons
                          .favorite_border_rounded,
                      color: isSaved
                          ? AppColors.error
                          : AppColors
                          .textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // =========================================
              // AMOUNT
              // =========================================

              Row(
                children: [

                  Icon(
                    Icons.currency_rupee_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    widget.amount.isEmpty
                        ? "Amount not specified"
                        : widget.amount,

                    style:
                    AppTextStyles.subtitle.copyWith(
                      fontSize: 14,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      AppColors.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // =========================================
              // DEADLINE
              // =========================================

              Row(
                children: [

                  Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color:
                    AppColors.textSecondary,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    widget.lastDate.isEmpty
                        ? "Deadline not specified"
                        : "Deadline: ${widget.lastDate}",

                    style:
                    AppTextStyles.subtitle.copyWith(
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =========================================
              // ELIGIBILITY
              // =========================================

              if (widget.eligibility.isNotEmpty)
                Container(
                  width: double.infinity,

                  padding:
                  const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: AppColors.secondary
                        .withOpacity(0.08),

                    borderRadius:
                    BorderRadius.circular(12),
                  ),

                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color:
                        AppColors.secondary,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          widget.eligibility,

                          style: AppTextStyles
                              .subtitle
                              .copyWith(
                            fontSize: 12,
                            color:
                            AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // =========================================
              // SAVED STATUS
              // =========================================

              Container(
                width: double.infinity,

                padding:
                const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),

                decoration: BoxDecoration(
                  color: isSaved
                      ? AppColors.error
                      .withOpacity(0.08)
                      : AppColors.success
                      .withOpacity(0.08),

                  borderRadius:
                  BorderRadius.circular(10),
                ),

                child: Row(
                  children: [

                    Icon(
                      isSaved
                          ? Icons.favorite_rounded
                          : Icons.check_circle_rounded,

                      size: 17,

                      color: isSaved
                          ? AppColors.error
                          : AppColors.success,
                    ),

                    const SizedBox(width: 7),

                    Text(
                      isSaved
                          ? "Saved"
                          : "Eligible for you",

                      style:
                      AppTextStyles.subtitle.copyWith(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w600,
                        color: isSaved
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}