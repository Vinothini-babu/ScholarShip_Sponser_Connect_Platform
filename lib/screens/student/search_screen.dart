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
  final TextEditingController searchController =
  TextEditingController();

  final ScholarshipService _service =
  ScholarshipService();

  final ApplicationService _applicationService =
  ApplicationService();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,

        title: Text(
          "Search Scholarships",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),

        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ),

        child: Column(
          children: [

            // ==========================================
            // SEARCH FIELD
            // ==========================================

            TextField(
              controller: searchController,

              onChanged: (_) {
                setState(() {});
              },

              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),

              decoration: InputDecoration(
                hintText:
                "Search Scholarship...",

                hintStyle:
                AppTextStyles.subtitle.copyWith(
                  fontSize: 14,
                ),

                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),

                suffixIcon:
                searchController.text.isNotEmpty
                    ? IconButton(
                  onPressed: () {
                    searchController.clear();

                    setState(() {});
                  },

                  icon: Icon(
                    Icons.clear_rounded,
                    color:
                    AppColors.textSecondary,
                  ),
                )
                    : null,

                filled: true,
                fillColor: AppColors.card,

                contentPadding:
                const EdgeInsets.symmetric(
                  vertical: 14,
                ),

                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(16),

                  borderSide: BorderSide(
                    color: AppColors.textSecondary
                        .withOpacity(0.15),
                  ),
                ),

                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(16),

                  borderSide: BorderSide(
                    color: AppColors.textSecondary
                        .withOpacity(0.15),
                  ),
                ),

                focusedBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(16),

                  borderSide: BorderSide(
                    color: AppColors.secondary,
                    width: 1.6,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==========================================
            // SCHOLARSHIP LIST
            // ==========================================

            Expanded(
              child:
              StreamBuilder<List<ScholarshipModel>>(
                stream:
                _service.getScholarships(),

                builder: (
                    context,
                    snapshot,
                    ) {

                  // ======================================
                  // LOADING
                  // ======================================

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(
                      child:
                      CircularProgressIndicator(
                        color:
                        AppColors.primary,
                      ),
                    );
                  }

                  // ======================================
                  // ERROR
                  // ======================================

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding:
                        const EdgeInsets.all(20),

                        child: Text(
                          "Something went wrong.\n\n"
                              "${snapshot.error}",

                          textAlign:
                          TextAlign.center,

                          style:
                          AppTextStyles.subtitle,
                        ),
                      ),
                    );
                  }

                  // ======================================
                  // NO DATA
                  // ======================================

                  if (!snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        "No Scholarships Available",
                        style:
                        AppTextStyles.subtitle,
                      ),
                    );
                  }

                  // ======================================
                  // ALL SCHOLARSHIPS
                  // ======================================

                  final scholarships =
                  snapshot.data!;

                  // ======================================
                  // SEARCH FILTER
                  // ======================================

                  final searchText =
                  searchController.text
                      .trim()
                      .toLowerCase();

                  final filteredScholarships =
                  scholarships.where((scholarship) {

                    if (searchText.isEmpty) {
                      return true;
                    }

                    final title =
                    scholarship.title
                        .toLowerCase();

                    final description =
                    scholarship.description
                        .toLowerCase();

                    final eligibility =
                    scholarship.eligibility
                        .toLowerCase();

                    final sponsorName =
                    scholarship.sponsorName
                        .toLowerCase();

                    return title.contains(
                      searchText,
                    ) ||
                        description.contains(
                          searchText,
                        ) ||
                        eligibility.contains(
                          searchText,
                        ) ||
                        sponsorName.contains(
                          searchText,
                        );
                  }).toList();

                  // ======================================
                  // NO SEARCH RESULT
                  // ======================================

                  if (filteredScholarships.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize:
                        MainAxisSize.min,

                        children: [

                          Icon(
                            Icons.search_off_rounded,
                            size: 55,
                            color:
                            AppColors.textSecondary,
                          ),

                          const SizedBox(height: 12),

                          Text(
                            "No Scholarships Found",
                            style:
                            AppTextStyles.title
                                .copyWith(
                              fontSize: 18,
                              color:
                              AppColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "Try another scholarship name.",
                            style:
                            AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    );
                  }

                  // ======================================
                  // DISPLAY LIST
                  // ======================================

                  return ListView.builder(
                    padding:
                    const EdgeInsets.only(
                      bottom: 20,
                    ),

                    itemCount:
                    filteredScholarships.length,

                    itemBuilder:
                        (context, index) {

                      final scholarship =
                      filteredScholarships[index];

                      return _ScholarshipTile(
                        id: scholarship.id,

                        title:
                        scholarship.title,

                        amount:
                        scholarship.amount,

                        deadline:
                        scholarship.lastDate,

                        icon:
                        Icons.school_rounded,

                        sponsorId:
                        scholarship.sponsorId,

                        applicationService:
                        _applicationService,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// SCHOLARSHIP TILE
// ==========================================================

class _ScholarshipTile
    extends StatefulWidget {

  final String id;

  final String title;

  final String amount;

  final String deadline;

  final IconData icon;

  final String sponsorId;

  final ApplicationService
  applicationService;

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
  State<_ScholarshipTile> createState() =>
      _ScholarshipTileState();
}

class _ScholarshipTileState
    extends State<_ScholarshipTile> {

  // ==========================================
  // SERVICES
  // ==========================================

  final SavedScholarshipService
  _savedService =
  SavedScholarshipService();

  // ==========================================
  // STATES
  // ==========================================

  bool _isSaved = false;

  bool _isSaving = false;

  bool _isApplying = false;

  // ==========================================
  // STREAM SUBSCRIPTION
  // ==========================================

  StreamSubscription<bool>?
  _savedSubscription;

  // ==========================================
  // INIT STATE
  // ==========================================

  @override
  void initState() {
    super.initState();

    _listenSavedStatus();
  }

  // ==========================================
  // LISTEN SAVED STATUS
  // ==========================================

  void _listenSavedStatus() {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _savedSubscription =
        _savedService
            .isSaved(
          studentId: user.uid,
          scholarshipId: widget.id,
        )
            .listen((saved) {

          if (!mounted) return;

          setState(() {
            _isSaved = saved;
          });
        });
  }

  // ==========================================
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    _savedSubscription?.cancel();

    super.dispose();
  }

  // ==========================================
  // TOGGLE SAVE
  // ==========================================

  Future<void> _toggleSave() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text("Please login first"),
        ),
      );

      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {

      // ========================================
      // REMOVE
      // ========================================

      if (_isSaved) {

        await _savedService
            .removeSavedScholarship(
          studentId: user.uid,
          scholarshipId: widget.id,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Scholarship removed from saved",
            ),
          ),
        );
      }

      // ========================================
      // SAVE
      // ========================================

      else {

        await _savedService
            .saveScholarship(
          studentId: user.uid,

          scholarshipId:
          widget.id,

          title:
          widget.title,

          amount:
          widget.amount,

          lastDate:
          widget.deadline,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "❤️ Scholarship saved",
            ),
          ),
        );
      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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
  // ==========================================
  // APPLY SCHOLARSHIP
  // ==========================================

  Future<void> _handleApply() async {

    if (_isApplying) return;

    setState(() {
      _isApplying = true;
    });

    try {

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          "User not logged in",
        );
      }

      // ========================================
      // GET STUDENT PROFILE
      // ========================================

      final profileDoc =
      await FirebaseFirestore.instance
          .collection("users")
          .doc("student")
          .collection(user.uid)
          .doc("profile")
          .get();

      final userData =
          profileDoc.data() ?? {};

      // ========================================
      // STUDENT DETAILS
      // ========================================

      final studentName =
          userData["name"] ??
              user.displayName ??
              "Student";

      final studentEmail =
          userData["email"] ??
              user.email ??
              "";

      final studentCollege =
          userData["college"] ??
              "";

      // ========================================
      // APPLICATION MODEL
      // ========================================

      final application =
      ApplicationModel(
        id: "",

        studentId:
        user.uid,

        studentName:
        studentName.toString(),

        studentEmail:
        studentEmail.toString(),

        studentCollege:
        studentCollege.toString(),

        sponsorId:
        widget.sponsorId,

        scholarshipId:
        widget.id,

        scholarshipTitle:
        widget.title,

        amount:
        widget.amount,

        status:
        "Pending",

        appliedAt:
        Timestamp.now(),
      );

      // ========================================
      // SUBMIT APPLICATION
      // ========================================

      final result =
      await widget.applicationService
          .applyScholarship(
        application,
      );

      if (!mounted) return;

      // ========================================
      // ALREADY APPLIED
      // ========================================

      if (result ==
          "Already Applied") {

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
            Text("⚠️ Already Applied"),
          ),
        );
      }

      // ========================================
      // SUCCESS
      // ========================================

      else if (result ==
          "Success") {

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "🎉 Application Submitted Successfully",
            ),
          ),
        );
      }

      // ========================================
      // OTHER RESULT
      // ========================================

      else {

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content:
            Text(result),
          ),
        );
      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            "Application failed: $e",
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

  // ==========================================
  // BUILD SCHOLARSHIP TILE
  // ==========================================

  @override
  Widget build(
      BuildContext context,
      ) {

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 16,
      ),

      padding:
      const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color:
        AppColors.card,

        borderRadius:
        BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.05,
            ),

            blurRadius: 12,

            offset:
            const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          // ========================================
          // TITLE + SAVE BUTTON
          // ========================================

          Row(
            children: [

              Container(
                width: 48,
                height: 48,

                decoration:
                BoxDecoration(
                  color: AppColors.secondary
                      .withOpacity(
                    0.15,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),

                child: Icon(
                  widget.icon,

                  color:
                  AppColors.primary,

                  size: 24,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Text(
                  widget.title,

                  maxLines: 2,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  AppTextStyles.subtitle
                      .copyWith(
                    color:
                    AppColors.textPrimary,

                    fontWeight:
                    FontWeight.bold,

                    fontSize: 16,
                  ),
                ),
              ),

              // ==================================
              // SAVE BUTTON
              // ==================================

              IconButton(
                onPressed:
                _isSaving
                    ? null
                    : _toggleSave,

                tooltip:
                _isSaved
                    ? "Remove from saved"
                    : "Save scholarship",

                icon:

                _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,

                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                  ),
                )

                    : Icon(
                  _isSaved
                      ? Icons
                      .favorite_rounded
                      : Icons
                      .favorite_border_rounded,

                  color:
                  _isSaved
                      ? AppColors
                      .error
                      : AppColors
                      .textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // ========================================
          // AMOUNT + DEADLINE
          // ========================================

          Row(
            children: [

              Icon(
                Icons
                    .currency_rupee_rounded,

                size: 15,

                color:
                AppColors.textSecondary,
              ),

              const SizedBox(
                width: 4,
              ),

              Text(
                widget.amount,

                style:
                AppTextStyles.subtitle
                    .copyWith(
                  color:
                  AppColors.textPrimary,

                  fontWeight:
                  FontWeight.w600,

                  fontSize: 14,
                ),
              ),

              const SizedBox(
                width: 18,
              ),

              Icon(
                Icons
                    .calendar_today_rounded,

                size: 13,

                color:
                AppColors.textSecondary,
              ),

              const SizedBox(
                width: 4,
              ),

              Expanded(
                child: Text(
                  widget.deadline,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  AppTextStyles.subtitle
                      .copyWith(
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          // ========================================
          // APPLY BUTTON
          // ========================================

          SizedBox(
            width:
            double.infinity,

            child:
            ElevatedButton(
              onPressed:
              _isApplying
                  ? null
                  : _handleApply,

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.primary,

                foregroundColor:
                Colors.white,

                disabledBackgroundColor:
                AppColors.primary
                    .withOpacity(
                  0.55,
                ),

                disabledForegroundColor:
                Colors.white,

                padding:
                const EdgeInsets.symmetric(
                  vertical: 14,
                ),

                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),

                elevation:
                0,
              ),

              child:

              _isApplying

                  ? const SizedBox(
                height: 18,
                width: 18,

                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,

                  color:
                  Colors.white,
                ),
              )

                  : const Text(
                "Apply",
              ),
            ),
          ),
        ],
      ),
    );
  }
}