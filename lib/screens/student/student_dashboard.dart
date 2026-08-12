import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

import 'search_screen.dart';
import 'application_screen.dart';
import 'profile_screen.dart';
import '../../models/scholarship_model.dart';
import '../../services/scholarship_service.dart';
import 'my_applications_screen.dart';
import '../../services/saved_scholarship_service.dart';
import 'saved/saved_scholarships_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _navIndex = 0;

  final ScholarshipService scholarshipService =
  ScholarshipService();

  void _handleNavTap(int index) {
    if (index == _navIndex) return;

    switch (index) {
      case 0:
        setState(() => _navIndex = 0);
        break;

      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ApplicationScreen()),
        );
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const _GradientHeader(userName: "Vino"),
                  Positioned(
                    bottom: -34,
                    left: 20,
                    right: 20,
                    child: const _PromoBanner(),
                  ),
                ],
              ),

              const SizedBox(height: 45),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const _StatsGrid(),
              ),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SectionHeader(
                  title: "Trending Scholarships",
                  actionLabel: "See All",
                  onAction: () {},
                ),
              ),

              const SizedBox(height: 18),

            SizedBox(
              height: 220,
              child: StreamBuilder<List<ScholarshipModel>>(
                stream: scholarshipService.getScholarships(),
                builder: (context, snapshot) {

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text("No Scholarships Available"),
                    );
                  }

                  print("Documents Count: ${snapshot.data?.length}");

                  final scholarships = snapshot.data!;

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: scholarships.length,

                    itemBuilder: (context, index) {

                      final scholarship = scholarships[index];
                      return _ScholarshipCard(
                        scholarshipId: scholarship.id,
                        title: scholarship.title,
                        amount: scholarship.amount,
                        deadline: scholarship.lastDate,
                        icon: Icons.school,
                        accent: AppColors.primary,
                        onTap: () {},
                      );
                    },
                  );
                },
              ),
            ),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const _SectionHeader(title: "Quick Actions"),
              ),

              const SizedBox(height: 18),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 500;
                    final crossAxisCount = isWide ? 4 : 2;

                    final actions = [
                      _QuickAction(
                        icon: Icons.assignment,
                        title: "My Applications",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyApplicationsScreen(),
                            ),
                          );
                        },
                      ),
                      _QuickAction(
                        icon: Icons.person,
                        title: "My Profile",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                      ),
                      _QuickAction(
                        icon: Icons.favorite,
                        title: "Saved",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SavedScholarshipsScreen(),
                            ),
                          );
                        },
                      ),
                      _QuickAction(
                        icon: Icons.support_agent,
                        title: "Support",
                        onTap: () {},
                      ),
                    ];

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: actions.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        // Fixed height regardless of width — stops the
                        // huge vertical gap that appeared on wide (desktop) windows.
                        mainAxisExtent: 60,
                      ),
                      itemBuilder: (context, index) => actions[index],
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _navIndex,
        onTap: _handleNavTap,
      ),
    );
  }
}

/// ------------------------------------------------------------
/// TAP ANIMATION
/// ------------------------------------------------------------

class _TapFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const _TapFeedback({
    required this.child,
    required this.borderRadius,
    this.onTap,
  });

  @override
  State<_TapFeedback> createState() => _TapFeedbackState();
}

class _TapFeedbackState extends State<_TapFeedback> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: hover ? 1.04 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap,
            splashColor: AppColors.secondary.withValues(alpha: .18),
            highlightColor: AppColors.secondary.withValues(alpha: .08),
            hoverColor: AppColors.secondary.withValues(alpha: .10),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// HEADER
/// ------------------------------------------------------------

class _GradientHeader extends StatelessWidget {
  final String userName;

  const _GradientHeader({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 55),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: .85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi, $userName 👋",
                style: AppTextStyles.title.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Let's find your next opportunity",
                style: AppTextStyles.subtitle.copyWith(color: Colors.white70),
              ),
            ],
          ),
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.secondary,
            child: Text(
              userName[0],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// PROMO CARD
/// ------------------------------------------------------------

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.secondary.withValues(alpha: .15),
              child: Icon(Icons.celebration, color: AppColors.secondary),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "50+ New Scholarships",
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("Added this week", style: AppTextStyles.subtitle),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
// =======================================================
// STATS GRID
// =======================================================

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    final studentId = FirebaseAuth.instance.currentUser?.uid;

    if (studentId == null) {
      return const SizedBox.shrink();
    }

    final firestore = FirebaseFirestore.instance;
    final savedService = SavedScholarshipService();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),

          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isDesktop ? 4.2 : 2.0,
          ),

          children: [

            // =================================================
            // SCHOLARSHIPS - REAL TIME
            // =================================================

            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection("scholarships")
                  .where("status", isEqualTo: "Active")
                  .snapshots(),

              builder: (context, snapshot) {

                final count =
                    snapshot.data?.docs.length ?? 0;

                return _buildStatCard(
                  icon: Icons.school_rounded,
                  title: "Scholarships",
                  value: "$count",
                  color: AppColors.primary,
                );
              },
            ),

            // =================================================
            // APPLIED - REAL TIME
            // =================================================

            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection("applications")
                  .where(
                "studentId",
                isEqualTo: studentId,
              )
                  .snapshots(),

              builder: (context, snapshot) {

                final count =
                    snapshot.data?.docs.length ?? 0;

                return _buildStatCard(
                  icon: Icons.assignment_turned_in_rounded,
                  title: "Applied",
                  value: "$count",
                  color: AppColors.success,
                );
              },
            ),

            // =================================================
            // SAVED - REAL TIME
            // =================================================

            StreamBuilder<int>(
              stream: savedService.getSavedCount(studentId),

              builder: (context, snapshot) {

                final count =
                    snapshot.data ?? 0;

                return _buildStatCard(
                  icon: Icons.favorite_rounded,
                  title: "Saved",
                  value: "$count",
                  color: AppColors.error,
                );
              },
            ),

            // =================================================
            // ELIGIBLE - REAL TIME
            // =================================================

            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection("scholarships")
                  .where("status", isEqualTo: "Active")
                  .snapshots(),

              builder: (context, scholarshipSnapshot) {

                return StreamBuilder<DocumentSnapshot>(
                  stream: firestore
                      .collection("users")
                      .doc(studentId)
                      .snapshots(),

                  builder: (context, userSnapshot) {

                    int eligibleCount = 0;

                    if (scholarshipSnapshot.hasData &&
                        userSnapshot.hasData &&
                        userSnapshot.data!.exists) {

                      final userData =
                      userSnapshot.data!.data()
                      as Map<String, dynamic>?;

                      final studentCollege =
                      (userData?["college"] ?? "")
                          .toString()
                          .toLowerCase();

                      final studentCourse =
                      (userData?["course"] ?? "")
                          .toString()
                          .toLowerCase();

                      for (final doc
                      in scholarshipSnapshot.data!.docs) {

                        final data =
                        doc.data()
                        as Map<String, dynamic>;

                        final eligibility =
                        (data["eligibility"] ?? "")
                            .toString()
                            .toLowerCase();

                        // If eligibility is empty,
                        // consider it available.
                        if (eligibility.isEmpty) {
                          eligibleCount++;
                          continue;
                        }

                        // Basic eligibility matching
                        if (eligibility.contains("all") ||
                            eligibility.contains(studentCollege) ||
                            eligibility.contains(studentCourse)) {
                          eligibleCount++;
                        }
                      }
                    }

                    return _buildStatCard(
                      icon: Icons.workspace_premium_rounded,
                      title: "Eligible",
                      value: "$eligibleCount",
                      color: AppColors.secondary,
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return _TapFeedback(
      borderRadius: BorderRadius.circular(16),

      onTap: () {},

      child: Container(
        padding: const EdgeInsets.all(10),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(
            color: color.withValues(alpha: .20),
            width: 1.2,
          ),

          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            CircleAvatar(
              radius: 13,

              backgroundColor:
              color.withValues(alpha: .15),

              child: Icon(
                icon,
                color: color,
                size: 14,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              value,
              style: AppTextStyles.title.copyWith(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),

            Text(
              title,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// SECTION HEADER
// =======================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.title.copyWith(fontSize: 19)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

// =======================================================
// SCHOLARSHIP CARD
// =======================================================

class _ScholarshipCard extends StatelessWidget {
  final String scholarshipId;
  final String title;
  final String amount;
  final String deadline;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ScholarshipCard({
    required this.scholarshipId,
    required this.title,
    required this.amount,
    required this.deadline,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: _TapFeedback(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 168,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: .18),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .13),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 58,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          accent.withValues(alpha: .75),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                  // ❤️ Save Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: StreamBuilder<bool>(
                      stream: SavedScholarshipService().isSaved(
                        studentId:
                        FirebaseAuth.instance.currentUser!.uid,
                        scholarshipId: scholarshipId,
                      ),
                      builder: (context, snapshot) {
                        final isSaved = snapshot.data ?? false;

                        return Material(
                          color: Colors.white.withValues(alpha: .90),
                          shape: const CircleBorder(),
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final service =
                              SavedScholarshipService();

                              final studentId =
                                  FirebaseAuth.instance.currentUser!.uid;

                              if (isSaved) {
                                await service.removeSavedScholarship(
                                  studentId: studentId,
                                  scholarshipId: scholarshipId,
                                );
                              } else {
                                await service.saveScholarship(
                                  studentId: studentId,
                                  scholarshipId: scholarshipId,
                                  title: title,
                                  amount: amount,
                                  lastDate: deadline,
                                );
                              }
                            },
                            icon: Icon(
                              isSaved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isSaved
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.currency_rupee, size: 15, color: accent),
                        Text(
                          amount,
                          style: AppTextStyles.subtitle.copyWith(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          deadline,
                          style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// QUICK ACTION
// =======================================================

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TapFeedback(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: .12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.secondary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// BOTTOM NAV
// =======================================================

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.home_rounded, label: "Home"),
      (icon: Icons.search_rounded, label: "Search"),
      (icon: Icons.assignment_rounded, label: "Applications"),
      (icon: Icons.person_rounded, label: "Profile"),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;

              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
