import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

import '../../../models/application_model.dart';
import '../../../services/application_service.dart';
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
    if (value == null) return 0;

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
              .doc(user.uid)
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

  final ApplicationService _applicationService =
  ApplicationService();

  bool _isApplying = false;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    try {
      final saved = await widget.savedService
          .isSaved(
        studentId: widget.studentId,
        scholarshipId: widget.scholarshipId,
      )
          .first;

      if (!mounted) return;

      setState(() {
        _isSaved = saved;
      });
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isSaved) {
        await widget.savedService.removeSavedScholarship(
          studentId: widget.studentId,
          scholarshipId: widget.scholarshipId,
        );
      } else {
        await widget.savedService.saveScholarship(
          studentId: widget.studentId,
          scholarshipId: widget.scholarshipId,
          title: widget.title,
          amount: widget.amount,
          lastDate: widget.lastDate,
        );
      }

      if (!mounted) return;

      setState(() {
        _isSaved = !_isSaved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSaved
                ? "Scholarship saved"
                : "Scholarship removed",
          ),
        ),
      );
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
  Future<void> _applyScholarship() async {
    if (_isApplying) return;

    setState(() {
      _isApplying = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("Please login again");
      }

      final firestore = FirebaseFirestore.instance;

      // =========================================================
      // GET STUDENT DATA
      // =========================================================

      final studentSnapshot = await firestore
          .collection("users")
          .doc(user.uid)
          .get();

      if (!studentSnapshot.exists) {
        throw Exception("Student profile not found");
      }

      final studentData = studentSnapshot.data() ?? {};

      // DEBUG
      print("====================================");
      print("Student UID: ${user.uid}");
      print("Student Name: ${studentData["name"]}");
      print("Student College: ${studentData["college"]}");
      print("Student Email: ${studentData["email"]}");
      print("====================================");

      // =========================================================
      // GET SCHOLARSHIP DATA
      // =========================================================

      final scholarshipSnapshot = await firestore
          .collection("scholarships")
          .doc(widget.scholarshipId)
          .get();

      if (!scholarshipSnapshot.exists) {
        throw Exception("Scholarship not found");
      }

      final scholarshipData =
          scholarshipSnapshot.data() ?? {};

      // =========================================================
      // GET SPONSOR ID
      // =========================================================

      final sponsorId =
          scholarshipData["sponsorId"]?.toString() ?? "";

      if (sponsorId.isEmpty) {
        throw Exception(
          "Sponsor information is missing",
        );
      }

      // =========================================================
      // CREATE APPLICATION
      // =========================================================

      final application = ApplicationModel(
        id: "",

        studentId: user.uid,

        studentName:
        studentData["name"]?.toString() ?? "",

        studentEmail:
        studentData["email"]?.toString() ??
            user.email ??
            "",

        studentCollege:
        studentData["college"]?.toString() ?? "",

        sponsorId: sponsorId,

        scholarshipId:
        widget.scholarshipId,

        scholarshipTitle:
        widget.title,

        amount:
        widget.amount,

        status: "Pending",

        appliedAt: Timestamp.now(),
      );

      // =========================================================
      // SAVE APPLICATION
      // =========================================================

      final result =
      await _applicationService
          .applyScholarship(application);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == "Success"
                ? "Application submitted successfully"
                : result == "Already Applied"
                ? "You already applied for this scholarship"
                : "Application failed: $result",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to apply: $e",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
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

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  widget.title,
                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    AppColors.textPrimary,
                  ),
                ),
              ),

              IconButton(
                onPressed:
                _isSaving ? null : _toggleSave,
                icon: Icon(
                  _isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color:
                  _isSaved
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Icon(
                Icons.currency_rupee_rounded,
                size: 16,
                color:
                AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                widget.amount,
                style:
                AppTextStyles.subtitle.copyWith(
                  fontWeight:
                  FontWeight.w600,
                  color:
                  AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color:
                AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                "Deadline: ${widget.lastDate}",
                style:
                AppTextStyles.subtitle.copyWith(
                  fontSize: 13,
                  color:
                  AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning
                  .withOpacity(0.08),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Text(
              widget.eligibility.isEmpty
                  ? "Eligible based on your profile"
                  : widget.eligibility,
              style:
              AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                color:
                AppColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(
              vertical: 9,
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.success
                  .withOpacity(0.08),
              borderRadius:
              BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color:
                  AppColors.success,
                ),
                const SizedBox(width: 7),
                Text(
                  "Eligible for you",
                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
              _isApplying
                  ? null
                  : _applyScholarship,
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.primary,
                foregroundColor:
                Colors.white,
                padding:
                const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              child: _isApplying
                  ? const SizedBox(
                width: 20,
                height: 20,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                "Apply Now",
                style: TextStyle(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}