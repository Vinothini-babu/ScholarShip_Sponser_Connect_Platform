import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'add_scholarship_screen.dart';
import 'manage_scholarship_screen.dart';
import 'applications/sponsor_applications_screen.dart';
import 'sponsor_profile_screen.dart';
import 'dashboard/approved_students_screen.dart';

class SponsorDashboard extends StatefulWidget {
  const SponsorDashboard({super.key});

  @override
  State<SponsorDashboard> createState() => _SponsorDashboardState();
}

class _SponsorDashboardState extends State<SponsorDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // 0 = header, 1..4 = quick action cards, 5..7 = stat cards, 8 = recent list
  static const int _itemCount = 9;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Wraps [child] with a fade + slide-up entrance, staggered by [index].
  Widget _reveal(int index, Widget child) {
    final start = (index / _itemCount) * 0.6;
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==============================
              // HEADER — gradient hero card, real-time org name/logo
              // ==============================
              _reveal(0, _SponsorHeader(uid: uid)),

              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(title: "Quick Actions"),
                      const SizedBox(height: 16),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 640;
                          final actionsData = [
                            (
                            icon: Icons.add_circle_rounded,
                            title: "Add Scholarship",
                            subtitle: "Publish a new opportunity",
                            gradient: [AppColors.primary, AppColors.primary.withOpacity(0.75)],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddScholarshipScreen()),
                            ),
                            ),
                            (
                            icon: Icons.list_alt_rounded,
                            title: "Manage",
                            subtitle: "Edit or remove listings",
                            gradient: [AppColors.secondary, AppColors.secondary.withOpacity(0.75)],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ManageScholarshipsScreen()),
                            ),
                            ),
                            (
                            icon: Icons.assignment_rounded,
                            title: "Applications",
                            subtitle: "Review student submissions",
                            gradient: [AppColors.success, AppColors.success.withOpacity(0.75)],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SponsorApplicationsScreen()),
                            ),
                            ),
                            (
                            icon: Icons.person_rounded,
                            title: "Profile",
                            subtitle: "Manage your organization",
                            gradient: [AppColors.error, AppColors.error.withOpacity(0.75)],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SponsorProfileScreen()),
                            ),
                            ),
                          ];

                          final actions = [
                            for (int i = 0; i < actionsData.length; i++)
                              _reveal(
                                1 + i,
                                _ActionCard(
                                  icon: actionsData[i].icon,
                                  title: actionsData[i].title,
                                  subtitle: actionsData[i].subtitle,
                                  gradient: actionsData[i].gradient,
                                  onTap: actionsData[i].onTap,
                                ),
                              ),
                          ];

                          // Always a 2x2 grid (2 cards on top, 2 below), and it
                          // stretches to fill whatever width is available —
                          // on a wide desktop window each card just gets bigger.
                          final gap = isWide ? 20.0 : 14.0;
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: actions[0]),
                                  SizedBox(width: gap),
                                  Expanded(child: actions[1]),
                                ],
                              ),
                              SizedBox(height: gap),
                              Row(
                                children: [
                                  Expanded(child: actions[2]),
                                  SizedBox(width: gap),
                                  Expanded(child: actions[3]),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                      const _SectionTitle(title: "Overview"),
                      const SizedBox(height: 16),

                      // ==============================
                      // LIVE STATS — StreamBuilder-backed, gradient-accented, animated counters
                      // ==============================
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("scholarships")
                            .where("sponsorId", isEqualTo: uid)
                            .snapshots(),
                        builder: (context, scholarshipSnapshot) {
                          final totalScholarships = scholarshipSnapshot.data?.docs.length ?? 0;

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("applications")
                                .where("sponsorId", isEqualTo: uid)
                                .snapshots(),
                            builder: (context, applicationSnapshot) {
                              final appDocs = applicationSnapshot.data?.docs ?? [];
                              final totalApplications = appDocs.length;
                              final approvedApplications = appDocs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return data["status"] == "Approved";
                              }).length;
                              final pendingApplications = appDocs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return data["status"] == "Pending";
                              }).length;

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 640;

                                  final statsData = [
                                    (
                                    icon: Icons.school_rounded,
                                    label: "Total Scholarships",
                                    value: totalScholarships,
                                    accent: AppColors.primary,
                                    badge: null as String?,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const ManageScholarshipsScreen()),
                                    ),
                                    ),
                                    (
                                    icon: Icons.assignment_rounded,
                                    label: "Applications Received",
                                    value: totalApplications,
                                    accent: AppColors.success,
                                    badge: pendingApplications > 0 ? "$pendingApplications pending" : null,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => SponsorApplicationsScreen()),
                                    ),
                                    ),
                                    (
                                    icon: Icons.check_circle_rounded,
                                    label: "Approved Students",
                                    value: approvedApplications,
                                    accent: AppColors.secondary,
                                    badge: null as String?,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ApprovedStudentsScreen()),
                                    ),
                                    ),
                                  ];

                                  final tiles = [
                                    for (int i = 0; i < statsData.length; i++)
                                      _reveal(
                                        5 + i,
                                        _StatCard(
                                          icon: statsData[i].icon,
                                          label: statsData[i].label,
                                          value: statsData[i].value,
                                          accent: statsData[i].accent,
                                          badge: statsData[i].badge,
                                          onTap: statsData[i].onTap,
                                        ),
                                      ),
                                  ];

                                  if (isWide) {
                                    return Row(
                                      children: tiles
                                          .map((t) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: t,
                                        ),
                                      ))
                                          .toList(),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      for (int i = 0; i < tiles.length; i++) ...[
                                        tiles[i],
                                        if (i != tiles.length - 1) const SizedBox(height: 12),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionTitle(title: "Recent Applications"),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SponsorApplicationsScreen()),
                            ),
                            icon: const Text("See all"),
                            label: const Icon(Icons.arrow_forward_rounded, size: 16),
                            iconAlignment: IconAlignment.start,
                            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ==============================
                      // RECENT APPLICATIONS — live feed, fills remaining space
                      // ==============================
                      _reveal(
                        8,
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("applications")
                              .where("sponsorId", isEqualTo: uid)
                              .limit(5)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const _RecentApplicationsCard(child: _LoadingRow());
                            }

                            final docs = List.of(snapshot.data!.docs);
                            // Sort client-side by submission time when present, newest first —
                            // avoids requiring a composite Firestore index.
                            docs.sort((a, b) {
                              final da = a.data() as Map<String, dynamic>;
                              final db = b.data() as Map<String, dynamic>;
                              final ta = da["submittedAt"] ?? da["appliedAt"] ?? da["createdAt"];
                              final tb = db["submittedAt"] ?? db["appliedAt"] ?? db["createdAt"];
                              if (ta is Timestamp && tb is Timestamp) {
                                return tb.compareTo(ta);
                              }
                              return 0;
                            });

                            if (docs.isEmpty) {
                              return const _RecentApplicationsCard(
                                child: _EmptyRow(
                                  icon: Icons.inbox_rounded,
                                  message: "No applications yet",
                                ),
                              );
                            }

                            return _RecentApplicationsCard(
                              child: Column(
                                children: [
                                  for (int i = 0; i < docs.length; i++) ...[
                                    _ApplicationRow(
                                      data: docs[i].data() as Map<String, dynamic>,
                                    ),
                                    if (i != docs.length - 1)
                                      Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================
// HEADER
// ==============================
class _SponsorHeader extends StatelessWidget {
  final String uid;
  const _SponsorHeader({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.82)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)),
            ),
          ),
          Positioned(
            right: 120,
            bottom: -60,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Welcome back 👋",
                    style: AppTextStyles.subtitle.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
                builder: (context, snapshot) {
                  String orgName = "Sponsor";
                  String? logoUrl;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    orgName = (data?["organizationName"] ?? data?["name"] ?? "Sponsor").toString();
                    logoUrl = data?["logoUrl"] as String?;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                          image: logoUrl != null && logoUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: (logoUrl == null || logoUrl.isEmpty)
                            ? Center(
                          child: Text(
                            orgName.isNotEmpty ? orgName[0].toUpperCase() : "S",
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          orgName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==============================
// SECTION TITLE
// ==============================
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.title.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ==============================
// QUICK ACTION CARD
// ==============================
class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            splashColor: widget.gradient.first.withOpacity(0.12),
            highlightColor: widget.gradient.first.withOpacity(0.06),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 160,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: radius,
                border: Border.all(color: Colors.black.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_hovering ? 0.10 : 0.05),
                    blurRadius: _hovering ? 20 : 10,
                    offset: Offset(0, _hovering ? 10 : 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58,
                    height: 58,
                    transform: Matrix4.identity()..scale(_hovering ? 1.08 : 1.0),
                    transformAlignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.gradient),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.gradient.first.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================
// STAT CARD — animated counter
// ==============================
class _StatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color accent;
  final String? badge;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.badge,
    this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            splashColor: widget.accent.withOpacity(0.10),
            highlightColor: widget.accent.withOpacity(0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: radius,
                border: Border(left: BorderSide(color: widget.accent, width: 4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_hovering ? 0.09 : 0.04),
                    blurRadius: _hovering ? 16 : 10,
                    offset: Offset(0, _hovering ? 8 : 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.accent.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.badge != null) ...[
                          const SizedBox(height: 4),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Container(
                              key: ValueKey(widget.badge),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.badge!,
                                style: TextStyle(color: widget.accent, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _AnimatedCount(value: widget.value),
                  if (widget.onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Counts up from 0 to [value] whenever the value changes.
class _AnimatedCount extends StatelessWidget {
  final int value;
  const _AnimatedCount({required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(
          "${animatedValue.round()}",
          style: AppTextStyles.title.copyWith(
            fontSize: 22,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        );
      },
    );
  }
}

// ==============================
// RECENT APPLICATIONS — card shell + rows
// ==============================
class _RecentApplicationsCard extends StatelessWidget {
  final Widget child;
  const _RecentApplicationsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _ApplicationRow extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ApplicationRow({required this.data});

  @override
  State<_ApplicationRow> createState() => _ApplicationRowState();
}

class _ApplicationRowState extends State<_ApplicationRow> {
  bool _hovering = false;

  Color _statusColor(String status) {
    switch (status) {
      case "Approved":
        return AppColors.success;
      case "Rejected":
        return AppColors.error;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = (widget.data["studentName"] ?? widget.data["name"] ?? "Student").toString();
    final scholarshipTitle =
    (widget.data["scholarshipTitle"] ?? widget.data["scholarshipName"] ?? "Scholarship").toString();
    final status = (widget.data["status"] ?? "Pending").toString();
    final color = _statusColor(status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovering ? Colors.black.withOpacity(0.015) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.13),
              child: Text(
                studentName.isNotEmpty ? studentName[0].toUpperCase() : "?",
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scholarshipTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                status,
                style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyRow({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}