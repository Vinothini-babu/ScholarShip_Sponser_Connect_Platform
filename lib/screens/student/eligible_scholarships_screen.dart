import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scholarship_sponser_connect_platform/screens/student/scholarship_applications_screen.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

import '../../../services/saved_scholarship_service.dart';
import '../../../utils/eligibility_utils.dart';
import 'scholarship_applications_screen.dart';

/// Fallback list used only for scholarships published before the
/// sponsor-defined "Required Documents" chip picker existed, so old
/// scholarships without a requiredDocuments field don't break.
const List<String> _legacyDefaultDocuments = [
  "Marksheet",
  "ID Proof",
  "Income Certificate",
  "College ID",
];

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

  bool _matches(
      Map<String, dynamic> scholarship,
      Map<String, dynamic> student,
      ) {
    // Shared with the student dashboard's trending-scholarship tap check,
    // so both places always agree on who counts as eligible.
    return isStudentEligibleForScholarship(scholarship, student);
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
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Eligible Scholarships",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 350 + (index * 80)),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 24),
                          child: child,
                        ),
                      );
                    },
                    child: _EligibleScholarshipCard(
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
                      requiredDocuments: (data["requiredDocuments"] is List &&
                          (data["requiredDocuments"] as List).isNotEmpty)
                          ? (data["requiredDocuments"] as List)
                          .map((e) => e.toString())
                          .toList()
                          : _legacyDefaultDocuments,
                      savedService: _savedService,
                      studentId: user.uid,
                    ),
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

            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.10),
              ),
              child: Icon(
                Icons.workspace_premium_outlined,
                size: 56,
                color: AppColors.secondary,
              ),
            ),

            const SizedBox(height: 20),

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
  final List<String> requiredDocuments;

  final SavedScholarshipService savedService;
  final String studentId;

  const _EligibleScholarshipCard({
    required this.scholarshipId,
    required this.title,
    required this.amount,
    required this.lastDate,
    required this.eligibility,
    required this.requiredDocuments,
    required this.savedService,
    required this.studentId,
  });

  @override
  State<_EligibleScholarshipCard> createState() =>
      _EligibleScholarshipCardState();
}


class _EligibleScholarshipCardState
    extends State<_EligibleScholarshipCard> {
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

  void _goToApplicationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScholarshipApplicationScreen(
          scholarshipId: widget.scholarshipId,
          title: widget.title,
          amount: widget.amount,
          lastDate: widget.lastDate,
          eligibility: widget.eligibility,
          requiredDocuments: widget.requiredDocuments,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : _toggleSave,
                icon: Icon(
                  _isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isSaved ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Icon(Icons.currency_rupee_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                widget.amount,
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                "Deadline: ${widget.lastDate}",
                style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.eligibility.isEmpty ? "Eligible based on your profile" : widget.eligibility,
              style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 17, color: AppColors.success),
                const SizedBox(width: 7),
                Text(
                  "Eligible for you",
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Documents are now filled out on a dedicated screen instead of
          // inline in this scrollable card list.
          Row(
            children: [
              Icon(Icons.folder_copy_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "${widget.requiredDocuments.length} document(s) required — fill them in on the next screen",
                  style: AppTextStyles.subtitle.copyWith(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.82)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _goToApplicationScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 17, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Apply Now",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}