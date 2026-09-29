import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/saved_scholarship_service.dart';

class SavedScholarshipsScreen extends StatelessWidget {
  SavedScholarshipsScreen({super.key});

  final SavedScholarshipService _service = SavedScholarshipService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login again")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder(
        stream: _service.getSavedScholarships(user.uid),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                // ---------------- HEADER + STAT ----------------
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Header(onBack: () => Navigator.pop(context)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -34,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 60),
                            child: _StatCard(
                              icon: Icons.favorite_rounded,
                              value: "${docs.length}",
                              label: "Saved Scholarships",
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 34 + 22),

                // ---------------- BODY ----------------
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildContent(context, snapshot, docs, user.uid),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      AsyncSnapshot snapshot,
      List docs,
      String uid,
      ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (snapshot.hasError) {
      debugPrint("SAVED SCHOLARSHIPS ERROR: ${snapshot.error}");
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            "Something went wrong\n${snapshot.error}",
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
        ),
      );
    }

    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 70,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                "No Saved Scholarships",
                style: AppTextStyles.title.copyWith(
                  fontSize: 19,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Save scholarships you're interested in and find them here.",
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width > 900 ? 3 : (width > 600 ? 2 : 1);
        const gap = 16.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final doc in docs)
              Builder(
                builder: (_) {
                  final data = (doc.data() as Map<String, dynamic>);
                  return SizedBox(
                    width: cardWidth,
                    child: _SavedScholarshipCard(
                      service: _service,
                      studentId: uid,
                      scholarshipId: (data["scholarshipId"] ?? "").toString(),
                      title: (data["title"] ?? "Scholarship").toString(),
                      amount: (data["amount"] ?? "").toString(),
                      lastDate: (data["lastDate"] ?? "").toString(),
                    ),
                  );
                },
              ),
          ],
        );
      },
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
                          "Saved Scholarships",
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
                      Icons.favorite_rounded,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Scholarships you've bookmarked to revisit later",
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

// =========================================================
// STAT CARD
// =========================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// SAVED SCHOLARSHIP CARD
// =========================================================

class _SavedScholarshipCard extends StatelessWidget {
  final SavedScholarshipService service;
  final String studentId;
  final String scholarshipId;
  final String title;
  final String amount;
  final String lastDate;

  const _SavedScholarshipCard({
    required this.service,
    required this.studentId,
    required this.scholarshipId,
    required this.title,
    required this.amount,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await service.removeSavedScholarship(
                          studentId: studentId,
                          scholarshipId: scholarshipId,
                        );
                      },
                      icon: Icon(
                        Icons.favorite_rounded,
                        color: AppColors.error,
                      ),
                      tooltip: "Remove from saved",
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Icon(
                      Icons.currency_rupee_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      amount,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Deadline: $lastDate",
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}