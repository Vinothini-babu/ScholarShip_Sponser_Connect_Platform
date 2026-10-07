import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/application_model.dart';
import '../../../services/application_service.dart';
import 'application_details_screen.dart';
import '../../common/chat_screen.dart';

/// Reads totalScore from the application data (0 for older applications
/// that were submitted before scoring existed).
double _scoreOf(ApplicationModel application) {
  final value = application.toMap()["totalScore"];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? "") ?? 0;
}

class SponsorApplicationsScreen extends StatefulWidget {
  const SponsorApplicationsScreen({super.key});

  @override
  State<SponsorApplicationsScreen> createState() =>
      _SponsorApplicationsScreenState();
}

class _SponsorApplicationsScreenState extends State<SponsorApplicationsScreen> {
  final ApplicationService _applicationService = ApplicationService();

  // All / Pending / Approved / Rejected
  String _filter = "All";

  @override
  Widget build(BuildContext context) {
    final sponsorId = FirebaseAuth.instance.currentUser?.uid;

    if (sponsorId == null) {
      return const Scaffold(
        body: Center(child: Text("Please login again")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<ApplicationModel>>(
        stream: _applicationService.getSponsorApplications(sponsorId),
        builder: (context, snapshot) {
          final all = snapshot.data ?? <ApplicationModel>[];

          final pending = all.where((a) => a.status == "Pending").length;
          final approved = all.where((a) => a.status == "Approved").length;
          final rejected = all.where((a) => a.status == "Rejected").length;

          // Filter, then highest totalScore first.
          final visible = all
              .where((a) => _filter == "All" || a.status == _filter)
              .toList()
            ..sort((a, b) => _scoreOf(b).compareTo(_scoreOf(a)));

          return SingleChildScrollView(
            child: Column(
              children: [
                // ---------------- HEADER + STATS ----------------
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Header(onBack: () => Navigator.pop(context)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -52,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SizedBox(
                              height: 104,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.assignment_rounded,
                                      value: "${all.length}",
                                      label: "Total Applications",
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.hourglass_top_rounded,
                                      value: "$pending",
                                      label: "Pending Review",
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.check_circle_rounded,
                                      value: "$approved",
                                      label: "Approved",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 52 + 22),

                // ---------------- BODY ----------------
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Filter chips
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _FilterChip(
                                label: "All",
                                count: all.length,
                                selected: _filter == "All",
                                onTap: () => setState(() => _filter = "All"),
                              ),
                              _FilterChip(
                                label: "Pending",
                                count: pending,
                                selected: _filter == "Pending",
                                onTap: () =>
                                    setState(() => _filter = "Pending"),
                              ),
                              _FilterChip(
                                label: "Approved",
                                count: approved,
                                selected: _filter == "Approved",
                                onTap: () =>
                                    setState(() => _filter = "Approved"),
                              ),
                              _FilterChip(
                                label: "Rejected",
                                count: rejected,
                                selected: _filter == "Rejected",
                                onTap: () =>
                                    setState(() => _filter = "Rejected"),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Text(
                            "Sorted by highest score",
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          const SizedBox(height: 16),

                          _buildContent(snapshot, visible),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
      AsyncSnapshot<List<ApplicationModel>> snapshot,
      List<ApplicationModel> visible,
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
      return Padding(
        padding: const EdgeInsets.all(25),
        child: Center(
          child: Text(
            "Unable to load applications.\n\n${snapshot.error}",
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
        ),
      );
    }

    if (visible.isEmpty) {
      return _emptyState();
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
            for (final application in visible)
              SizedBox(
                width: cardWidth,
                child: _ApplicationCard(application: application),
              ),
          ],
        );
      },
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 70,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              _filter == "All"
                  ? "No Applications Yet"
                  : "No $_filter Applications",
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(
                fontSize: 19,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Student applications for your scholarships will appear here.",
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle,
            ),
          ],
        ),
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
      height: 250,
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
          Positioned(left: -40, top: 90, child: _circle(150)),
          Positioned(right: -30, top: -30, child: _circle(140)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
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
                          "Applications Received",
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
                ),
                const SizedBox(height: 8),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: AppColors.secondary, width: 2),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in_rounded,
                    color: AppColors.secondary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Review Student Applications",
                  style: AppTextStyles.title.copyWith(
                    fontSize: 21,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Check scores, documents and decide who receives your scholarships",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
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
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// FILTER CHIP
// =========================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.18),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.textSecondary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "$count",
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// APPLICATION CARD
// =========================================================

class _ApplicationCard extends StatelessWidget {
  final ApplicationModel application;

  const _ApplicationCard({required this.application});

  Color _statusColor() {
    switch (application.status) {
      case "Approved":
        return AppColors.success;
      case "Rejected":
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  IconData _statusIcon() {
    switch (application.status) {
      case "Approved":
        return Icons.check_circle_rounded;
      case "Rejected":
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  String _formatDate() {
    final date = application.appliedAt.toDate();
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  Widget _infoRow(IconData icon, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: bold ? AppColors.textPrimary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final score = _scoreOf(application);

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
          // gradient strip, same look as the My Scholarships cards
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
                // ----- student + status -----
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
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        application.studentName.isEmpty
                            ? "Student"
                            : application.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(), size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            application.status,
                            style: AppTextStyles.subtitle.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ----- scholarship title -----
                Text(
                  application.scholarshipTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                _infoRow(
                  Icons.currency_rupee_rounded,
                  "Amount: ${application.amount}",
                  bold: true,
                ),
                _infoRow(
                  Icons.account_balance_rounded,
                  application.studentCollege.isEmpty
                      ? "College not available"
                      : application.studentCollege,
                ),
                _infoRow(
                  Icons.calendar_today_rounded,
                  "Applied: ${_formatDate()}",
                ),

                // ----- score bar -----
                if (score > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "Score",
                        style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        "${score.toStringAsFixed(1)} / 100",
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor:
                      AppColors.textSecondary.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        score >= 70
                            ? AppColors.success
                            : (score >= 50
                            ? AppColors.warning
                            : AppColors.error),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ----- view button -----
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ApplicationDetailsScreen(
                            data: application.toMap(),
                            applicationId: application.id,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary, width: 1.3),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "View Application",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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