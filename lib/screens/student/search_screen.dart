import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/scholarship_service.dart';
import '../../models/scholarship_model.dart';
import '../../services/application_service.dart';
import '../../services/saved_scholarship_service.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/application_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();

  final ScholarshipService _service = ScholarshipService();
  final ApplicationService _applicationService = ApplicationService();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(onBack: () => Navigator.pop(context)),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    children: [
                      // ==========================================
                      // SEARCH FIELD
                      // ==========================================
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setState(() {}),
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search Scholarship...",
                          hintStyle: AppTextStyles.subtitle.copyWith(fontSize: 14),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                            icon: Icon(
                              Icons.clear_rounded,
                              color: AppColors.textSecondary,
                            ),
                          )
                              : null,
                          filled: true,
                          fillColor: AppColors.card,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.secondary,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ==========================================
                      // SCHOLARSHIP LIST
                      // ==========================================
                      Expanded(
                        child: StreamBuilder<List<ScholarshipModel>>(
                          stream: _service.getScholarships(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    "Something went wrong.\n\n${snapshot.error}",
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.subtitle,
                                  ),
                                ),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Text(
                                  "No Scholarships Available",
                                  style: AppTextStyles.subtitle,
                                ),
                              );
                            }

                            final scholarships = snapshot.data!;

                            final searchText =
                            searchController.text.trim().toLowerCase();

                            final filteredScholarships =
                            scholarships.where((scholarship) {
                              if (searchText.isEmpty) return true;

                              final title = scholarship.title.toLowerCase();
                              final description =
                              scholarship.description.toLowerCase();
                              final eligibility =
                              scholarship.eligibility.toLowerCase();
                              final sponsorName =
                              scholarship.sponsorName.toLowerCase();

                              return title.contains(searchText) ||
                                  description.contains(searchText) ||
                                  eligibility.contains(searchText) ||
                                  sponsorName.contains(searchText);
                            }).toList();

                            if (filteredScholarships.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 55,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "No Scholarships Found",
                                      style: AppTextStyles.title.copyWith(
                                        fontSize: 18,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Try another scholarship name.",
                                      style: AppTextStyles.subtitle,
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: filteredScholarships.length,
                              itemBuilder: (context, index) {
                                final scholarship = filteredScholarships[index];

                                return _ScholarshipTile(
                                  id: scholarship.id,
                                  title: scholarship.title,
                                  amount: scholarship.amount,
                                  deadline: scholarship.lastDate,
                                  icon: Icons.school_rounded,
                                  sponsorId: scholarship.sponsorId,
                                  applicationService: _applicationService,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// HEADER
// =========================================================

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 210,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.82),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: -40, top: 60, child: _circle(120)),
          Positioned(right: -30, top: -20, child: _circle(120)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Search Scholarships",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title.copyWith(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(color: AppColors.secondary, width: 2),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Find scholarships by name, sponsor or eligibility",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
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

// ==========================================================
// SCHOLARSHIP TILE
// ==========================================================

class _ScholarshipTile extends StatefulWidget {
  final String id;
  final String title;
  final String amount;
  final String deadline;
  final IconData icon;
  final String sponsorId;
  final ApplicationService applicationService;

  const _ScholarshipTile({
    required this.id,
    required this.title,
    required this.amount,
    required this.deadline,
    required this.icon,
    required this.sponsorId,
    required this.applicationService,
  });

  @override
  State<_ScholarshipTile> createState() => _ScholarshipTileState();
}

class _ScholarshipTileState extends State<_ScholarshipTile> {
  final SavedScholarshipService _savedService = SavedScholarshipService();

  bool _isSaved = false;
  bool _isSaving = false;
  bool _isApplying = false;

  StreamSubscription<bool>? _savedSubscription;

  @override
  void initState() {
    super.initState();
    _listenSavedStatus();
  }

  void _listenSavedStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _savedSubscription = _savedService
        .isSaved(studentId: user.uid, scholarshipId: widget.id)
        .listen((saved) {
      if (!mounted) return;
      setState(() => _isSaved = saved);
    });
  }

  @override
  void dispose() {
    _savedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleSave() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (_isSaved) {
        await _savedService.removeSavedScholarship(
          studentId: user.uid,
          scholarshipId: widget.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Scholarship removed from saved")),
        );
      } else {
        await _savedService.saveScholarship(
          studentId: user.uid,
          scholarshipId: widget.id,
          title: widget.title,
          amount: widget.amount,
          lastDate: widget.deadline,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❤️ Scholarship saved")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to save scholarship: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleApply() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final profileDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc("student")
          .collection(user.uid)
          .doc("profile")
          .get();

      final userData = profileDoc.data() ?? {};

      final studentName = userData["name"] ?? user.displayName ?? "Student";
      final studentEmail = userData["email"] ?? user.email ?? "";
      final studentCollege = userData["college"] ?? "";

      final application = ApplicationModel(
        id: "",
        studentId: user.uid,
        studentName: studentName.toString(),
        studentEmail: studentEmail.toString(),
        studentCollege: studentCollege.toString(),
        sponsorId: widget.sponsorId,
        scholarshipId: widget.id,
        scholarshipTitle: widget.title,
        amount: widget.amount,
        status: "Pending",
        appliedAt: Timestamp.now(),
        documents: {},
      );

      final result =
      await widget.applicationService.applyScholarship(application);

      if (!mounted) return;

      if (result == "Already Applied") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Already Applied")),
        );
      } else if (result == "Success") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 Application Submitted Successfully"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Application failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // gradient strip, matching the other redesigned screens
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE + SAVE BUTTON
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.icon,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving ? null : _toggleSave,
                      tooltip: _isSaved ? "Remove from saved" : "Save scholarship",
                      icon: _isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Icon(
                        _isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isSaved
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // AMOUNT + DEADLINE
                Row(
                  children: [
                    Icon(
                      Icons.currency_rupee_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.amount,
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.deadline,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // APPLY BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isApplying ? null : _handleApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      AppColors.primary.withOpacity(0.55),
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isApplying
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text("Apply"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}