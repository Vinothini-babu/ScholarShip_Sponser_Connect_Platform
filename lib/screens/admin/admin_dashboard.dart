// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

import 'manage_students_screen.dart';
import 'manage_sponsors_screen.dart';
import 'manage_scholarships_screen.dart';
import 'view_applications_screen.dart';
import 'reports_screen.dart';
import 'contact_directory_screen.dart';
import 'admin_feedback_screen.dart';
import '../../services/feedback_service.dart';

// ================================================================
// HELPERS
// ================================================================

/// Indian digit grouping: 120000 -> 1,20,000
String _formatInr(num value) {
  final n = value.round();
  final s = n.abs().toString();
  final sign = n < 0 ? "-" : "";
  if (s.length <= 3) return "$sign$s";

  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return "$sign${parts.join(',')},$last3";
}

double _parseAmount(dynamic raw) {
  if (raw is num) return raw.toDouble();
  final cleaned = raw?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '';
  return double.tryParse(cleaned) ?? 0;
}

int _millis(dynamic v) => v is Timestamp ? v.millisecondsSinceEpoch : 0;

double _unit(double v) => math.max(0.0, math.min(1.0, v));

String _firstNonEmpty(List<dynamic> values, String fallback) {
  for (final v in values) {
    final s = v?.toString().trim() ?? "";
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

String _normalizeStatus(dynamic raw) {
  final s = raw?.toString().trim().toLowerCase() ?? "pending";
  if (s == "approved") return "Approved";
  if (s == "rejected" || s == "reject") return "Rejected";
  return "Pending";
}

Color _statusColor(String status) {
  switch (status) {
    case "Approved":
      return Colors.green;
    case "Rejected":
      return Colors.red;
    default:
      return Colors.orange;
  }
}

Widget _responsiveGrid(
    List<Widget> items, {
      required double maxWidth,
      required double breakpoint,
      required int narrowColumns,
      double gap = 14,
    }) {
  if (maxWidth > breakpoint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: items[i]),
        ],
      ],
    );
  }

  final rows = <Widget>[];
  for (int i = 0; i < items.length; i += narrowColumns) {
    final chunk = items.skip(i).take(narrowColumns).toList();
    rows.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int j = 0; j < narrowColumns; j++) ...[
            if (j > 0) SizedBox(width: gap),
            Expanded(
              child: j < chunk.length ? chunk[j] : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
    if (i + narrowColumns < items.length) {
      rows.add(SizedBox(height: gap));
    }
  }
  return Column(children: rows);
}

// ================================================================
// DATA MODEL (computed once from the three Firestore streams)
// ================================================================

class _AdminData {
  final int users;
  final int sponsors;
  final int scholarships;
  final int applications;
  final int pending;
  final int approved;
  final int rejected;
  final double totalFunds;
  final List<Map<String, dynamic>> recentApplications;
  final List<Map<String, dynamic>> recentScholarships;
  final bool applicationsLoading;
  final bool scholarshipsLoading;

  const _AdminData({
    required this.users,
    required this.sponsors,
    required this.scholarships,
    required this.applications,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.totalFunds,
    required this.recentApplications,
    required this.recentScholarships,
    required this.applicationsLoading,
    required this.scholarshipsLoading,
  });

  double get approvalRate => applications == 0 ? 0 : approved / applications;

  factory _AdminData.from(
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> usersSnap,
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> scholarshipSnap,
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> applicationSnap,
      ) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs =
        usersSnap.data?.docs ?? [];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> scholarshipDocs =
        scholarshipSnap.data?.docs ?? [];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> applicationDocs =
        applicationSnap.data?.docs ?? [];

    final List<Map<String, dynamic>> users =
    userDocs.map((d) => d.data()).toList();
    final List<Map<String, dynamic>> scholarships =
    scholarshipDocs.map((d) => d.data()).toList();
    final List<Map<String, dynamic>> applications =
    applicationDocs.map((d) => d.data()).toList();

    int sponsors = 0;
    for (final u in users) {
      if (u["role"] == "sponsor") sponsors++;
    }

    double funds = 0;
    for (final s in scholarships) {
      funds += _parseAmount(s["amount"]);
    }

    int pending = 0;
    int approved = 0;
    int rejected = 0;
    for (final a in applications) {
      final status = _normalizeStatus(a["status"]);
      if (status == "Approved") {
        approved++;
      } else if (status == "Rejected") {
        rejected++;
      } else {
        pending++;
      }
    }

    final List<Map<String, dynamic>> sortedApps = [...applications];
    sortedApps.sort(
          (a, b) => _millis(b["appliedAt"]).compareTo(_millis(a["appliedAt"])),
    );

    final List<Map<String, dynamic>> sortedScholarships = [...scholarships];
    sortedScholarships.sort(
          (a, b) => _millis(b["createdAt"]).compareTo(_millis(a["createdAt"])),
    );

    return _AdminData(
      users: users.length,
      sponsors: sponsors,
      scholarships: scholarships.length,
      applications: applications.length,
      pending: pending,
      approved: approved,
      rejected: rejected,
      totalFunds: funds,
      recentApplications: sortedApps.take(5).toList(),
      recentScholarships: sortedScholarships.take(4).toList(),
      applicationsLoading: applicationSnap.connectionState ==
          ConnectionState.waiting &&
          !applicationSnap.hasData,
      scholarshipsLoading: scholarshipSnap.connectionState ==
          ConnectionState.waiting &&
          !scholarshipSnap.hasData,
    );
  }
}

// ================================================================
// SCREEN
// ================================================================

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  // 0 header, 1 title, 2 stats, 3 reports spotlight, 4 status,
  // 5 recent applications, 6 recent scholarships, 7 quick actions
  static const int _sectionCount = 8;

  late final AnimationController _controller;
  late final List<Animation<double>> _reveals;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _scholarshipsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _applicationsStream;

  @override
  void initState() {
    super.initState();

    final db = FirebaseFirestore.instance;
    _usersStream = db.collection("users").snapshots();
    _scholarshipsStream = db.collection("scholarships").snapshots();
    _applicationsStream = db.collection("applications").snapshots();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();

    _reveals = List.generate(_sectionCount, (i) {
      final start = (i / _sectionCount) * 0.6;
      final end = math.min(start + 0.4, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fade + slide-up entrance, staggered by section index.
  Widget _reveal(int index, Widget child) {
    final animation = _reveals[index];
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }

  void _go(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (context, usersSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _scholarshipsStream,
              builder: (context, scholarshipSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _applicationsStream,
                  builder: (context, applicationSnap) {
                    final data = _AdminData.from(
                      usersSnap,
                      scholarshipSnap,
                      applicationSnap,
                    );
                    return _buildBody(data);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(_AdminData d) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- HEADER ----------------
          _reveal(
            0,
            _AdminHeader(
              pending: d.pending,
              onBellTap: () => _go(
                const ViewApplicationsScreen(initialFilter: "Pending"),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- TITLE ----------------
                _reveal(
                  1,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Admin Control Center",
                              style: AppTextStyles.title.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Monitor and manage the scholarship platform",
                              style: AppTextStyles.subtitle.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const _LiveBadge(),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------- STATS ----------------
                _reveal(2, _buildStatistics(d)),

                const SizedBox(height: 28),

                // ---------------- REPORTS SPOTLIGHT ----------------
                _reveal(
                  3,
                  _ReportsSpotlight(
                    approvalRate: d.approvalRate,
                    totalFunds: d.totalFunds,
                    pending: d.pending,
                    onTap: () => _go(const ReportsScreen()),
                  ),
                ),

                const SizedBox(height: 32),

                // ---------------- APPLICATION STATUS ----------------
                _reveal(
                  4,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(title: "Application Status"),
                      const SizedBox(height: 14),
                      _buildApplicationStatus(d),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ---------------- RECENT APPLICATIONS ----------------
                _reveal(
                  5,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: "Recent Applications",
                        actionText: "View All",
                        onAction: () => _go(const ViewApplicationsScreen()),
                      ),
                      const SizedBox(height: 14),
                      _buildRecentApplications(d),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ---------------- RECENT SCHOLARSHIPS ----------------
                _reveal(
                  6,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: "Recent Scholarships",
                        actionText: "Manage",
                        onAction: () => _go(const ManageScholarshipsScreen()),
                      ),
                      const SizedBox(height: 14),
                      _buildRecentScholarships(d),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ---------------- QUICK ACTIONS ----------------
                _reveal(
                  7,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(title: "Quick Actions"),
                      const SizedBox(height: 14),
                      _buildQuickActions(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics(_AdminData d) {
    final cards = <Widget>[
      _StatCard(
        icon: Icons.people_alt_rounded,
        title: "Total Users",
        value: d.users,
        accent: Colors.blue,
      ),
      _StatCard(
        icon: Icons.school_rounded,
        title: "Scholarships",
        value: d.scholarships,
        accent: Colors.orange,
      ),
      _StatCard(
        icon: Icons.assignment_rounded,
        title: "Applications",
        value: d.applications,
        accent: Colors.green,
      ),
      _StatCard(
        icon: Icons.business_rounded,
        title: "Sponsors",
        value: d.sponsors,
        accent: Colors.purple,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return _responsiveGrid(
          cards,
          maxWidth: constraints.maxWidth,
          breakpoint: 800,
          narrowColumns: 2,
          gap: 14,
        );
      },
    );
  }

  // ============================================================
  // APPLICATION STATUS
  // ============================================================

  Widget _buildApplicationStatus(_AdminData d) {
    final cards = <Widget>[
      _StatusCard(
        icon: Icons.hourglass_top_rounded,
        title: "Pending",
        count: d.pending,
        total: d.applications,
        color: Colors.orange,
        onTap: () =>
            _go(const ViewApplicationsScreen(initialFilter: "Pending")),
      ),
      _StatusCard(
        icon: Icons.check_circle_rounded,
        title: "Approved",
        count: d.approved,
        total: d.applications,
        color: Colors.green,
        onTap: () =>
            _go(const ViewApplicationsScreen(initialFilter: "Approved")),
      ),
      _StatusCard(
        icon: Icons.cancel_rounded,
        title: "Rejected",
        count: d.rejected,
        total: d.applications,
        color: Colors.red,
        onTap: () =>
            _go(const ViewApplicationsScreen(initialFilter: "Rejected")),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return _responsiveGrid(
          cards,
          maxWidth: constraints.maxWidth,
          breakpoint: 700,
          narrowColumns: 1,
          gap: 14,
        );
      },
    );
  }

  // ============================================================
  // RECENT APPLICATIONS
  // ============================================================

  Widget _buildRecentApplications(_AdminData d) {
    if (d.applicationsLoading) return const _LoadingCard();

    if (d.recentApplications.isEmpty) {
      return const _EmptyCard(
        icon: Icons.assignment_outlined,
        message: "No applications yet",
      );
    }

    return Column(
      children: [
        for (int i = 0; i < d.recentApplications.length; i++)
          _ApplicationTile(
            index: i,
            data: d.recentApplications[i],
            onTap: () => _go(const ViewApplicationsScreen()),
          ),
      ],
    );
  }

  // ============================================================
  // RECENT SCHOLARSHIPS
  // ============================================================

  Widget _buildRecentScholarships(_AdminData d) {
    if (d.scholarshipsLoading) return const _LoadingCard();

    if (d.recentScholarships.isEmpty) {
      return const _EmptyCard(
        icon: Icons.school_outlined,
        message: "No scholarships available",
      );
    }

    return Column(
      children: [
        for (int i = 0; i < d.recentScholarships.length; i++)
          _ScholarshipTile(
            index: i,
            data: d.recentScholarships[i],
            onTap: () => _go(const ManageScholarshipsScreen()),
          ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    final actions = <Widget>[
      _QuickActionCard(
        icon: Icons.call_rounded,
        title: "Call Students",
        subtitle: "Live contact list",
        color: Colors.indigo,
        highlighted: true,
        onTap: () => _go(
          const ContactDirectoryScreen(
            role: "student",
            title: "Call Students",
            color: Colors.indigo,
            icon: Icons.people_alt_rounded,
          ),
        ),
      ),
      _QuickActionCard(
        icon: Icons.phone_in_talk_rounded,
        title: "Call Sponsors",
        subtitle: "Live contact list",
        color: Colors.pink,
        highlighted: true,
        onTap: () => _go(
          const ContactDirectoryScreen(
            role: "sponsor",
            title: "Call Sponsors",
            color: Colors.pink,
            icon: Icons.business_rounded,
          ),
        ),
      ),
      // Sponsors waiting for admin verification (live count)
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .where("role", isEqualTo: "sponsor")
            .where("verificationStatus", isEqualTo: "pending")
            .snapshots(),
        builder: (context, snap) {
          final n = snap.data?.docs.length ?? 0;
          return _QuickActionCard(
            icon: Icons.verified_user_rounded,
            title: "Verify Sponsors",
            subtitle: n > 0 ? "$n awaiting verification" : "All sponsors reviewed",
            color: Colors.teal,
            highlighted: n > 0,
            onTap: () => _go(const ManageSponsorsScreen()),
          );
        },
      ),
      StreamBuilder<int>(
        stream: FeedbackService().newCount(),
        builder: (context, snap) {
          final n = snap.data ?? 0;
          return _QuickActionCard(
            icon: Icons.reviews_rounded,
            title: "Feedback",
            subtitle: n > 0 ? "$n new to review" : "Ratings & comments",
            color: Colors.amber.shade800,
            highlighted: n > 0,
            onTap: () => _go(const AdminFeedbackScreen()),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return _responsiveGrid(
          actions,
          maxWidth: constraints.maxWidth,
          breakpoint: 750,
          narrowColumns: 2,
          gap: 12,
        );
      },
    );
  }
}

// ================================================================
// HEADER (animated gradient, orbs, twinkles, shimmer title)
// ================================================================

class _AdminHeader extends StatefulWidget {
  final int pending;
  final VoidCallback onBellTap;

  const _AdminHeader({required this.pending, required this.onBellTap});

  @override
  State<_AdminHeader> createState() => _AdminHeaderState();
}

class _AdminHeaderState extends State<_AdminHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Widget _twinkle(
      double t,
      double phase, {
        double? right,
        double? top,
        double? left,
        double? bottom,
        double size = 4,
      }) {
    final o = 0.15 + 0.5 * (0.5 + 0.5 * math.sin(t * 2 + phase));
    return Positioned(
      right: right,
      top: top,
      left: left,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(o),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(o * 0.8), blurRadius: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.secondary;

    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final v = _loop.value;
        final t = 2 * math.pi * v;
        final drift = math.sin(t);
        final drift2 = math.cos(t);
        final pulse = 0.5 + 0.5 * math.sin(t * 3);

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 0.5 * drift, -1),
              end: Alignment(1, 1 + 0.4 * drift2),
              colors: [
                AppColors.primary,
                Color.lerp(AppColors.primary, gold, 0.16)!,
                AppColors.primary.withOpacity(0.88),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -30 + 14 * drift,
                top: -50 + 10 * drift2,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.03),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 140 + 16 * drift2,
                bottom: -60 + 8 * drift,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gold.withOpacity(0.10),
                  ),
                ),
              ),
              Positioned(
                left: 300 + 24 * drift,
                top: -34 + 6 * drift2,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              _twinkle(t, 0, right: 100, top: 30),
              _twinkle(t, 1.6, right: 230, top: 70, size: 3),
              _twinkle(t, 3.1, right: 60, bottom: 24, size: 5),
              _twinkle(t, 4.4, left: 380, bottom: 30, size: 3),

              Row(
                children: [
                  // avatar with glowing gold ring
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: gold.withOpacity(0.55 + 0.45 * pulse),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withOpacity(0.20 + 0.30 * pulse),
                          blurRadius: 10 + 12 * pulse,
                          spreadRadius: 1 + 2 * pulse,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Welcome Admin ",
                              style: AppTextStyles.subtitle.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.45 * math.sin(t * 4),
                              alignment: Alignment.bottomRight,
                              child: const Text(
                                "👋",
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment(-2 + 4 * v, 0),
                            end: Alignment(-1 + 4 * v, 0),
                            colors: const [
                              Colors.white,
                              Color(0xFFFFE7A0),
                              Colors.white,
                            ],
                          ).createShader(rect),
                          child: Text(
                            "Scholarship Sponsor Connect",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title.copyWith(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: gold.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 13,
                                color: gold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Platform Administrator",
                                style: AppTextStyles.subtitle.copyWith(
                                  color: Colors.white.withOpacity(0.92),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // bell with pending badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: IconButton(
                          tooltip: widget.pending > 0
                              ? "${widget.pending} pending application(s)"
                              : "No pending applications",
                          onPressed: widget.onBellTap,
                          icon: const Icon(
                            Icons.notifications_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      if (widget.pending > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Transform.scale(
                            scale: 1 + 0.12 * pulse,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                widget.pending > 99
                                    ? "99+"
                                    : "${widget.pending}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// LIVE BADGE (pulsing green dot)
// ================================================================

class _LiveBadge extends StatefulWidget {
  final bool onDark;
  const _LiveBadge({this.onDark = false});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.onDark ? Colors.white : Colors.green.shade700;
    final bg = widget.onDark
        ? Colors.white.withOpacity(0.14)
        : Colors.green.withOpacity(0.10);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.shade400,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.shade400
                          .withOpacity(0.35 + 0.45 * _c.value),
                      blurRadius: 4 + 6 * _c.value,
                      spreadRadius: 1 * _c.value,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "LIVE",
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// SECTION TITLE + LINK BUTTON
// ================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const _SectionTitle({required this.title, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.title.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionText != null && onAction != null)
          _LinkButton(text: actionText!, onTap: onAction!),
      ],
    );
  }
}

class _LinkButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _LinkButton({required this.text, required this.onTap});

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovering
                ? AppColors.primary.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: _hovering ? 8 : 3,
                height: 1,
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// COUNT-UP TEXT
// ================================================================

class _CountUp extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String Function(double) format;
  final Duration duration;

  const _CountUp({
    required this.value,
    required this.style,
    this.format = _defaultFormat,
    this.duration = const Duration(milliseconds: 900),
  });

  static String _defaultFormat(double v) => "${v.round()}";

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(format(animated), style: style),
    );
  }
}

// ================================================================
// STAT CARD
// ================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int value;
  final Color accent;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -44,
            top: -44,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.07),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0.75)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _CountUp(
                      value: value.toDouble(),
                      style: AppTextStyles.title.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REPORTS SPOTLIGHT — the highlighted, main feature card
// ================================================================

class _ReportsSpotlight extends StatefulWidget {
  final double approvalRate;
  final double totalFunds;
  final int pending;
  final VoidCallback onTap;

  const _ReportsSpotlight({
    required this.approvalRate,
    required this.totalFunds,
    required this.pending,
    required this.onTap,
  });

  @override
  State<_ReportsSpotlight> createState() => _ReportsSpotlightState();
}

class _ReportsSpotlightState extends State<_ReportsSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.secondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.012 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final t = 2 * math.pi * _loop.value;
              final pulse = 0.5 + 0.5 * math.sin(t * 2);

              return Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(AppColors.primary, Colors.black, 0.18)!,
                      AppColors.primary,
                      Color.lerp(AppColors.primary, gold, 0.22)!,
                    ],
                  ),
                  border: Border.all(
                    color: gold.withOpacity(0.35 + 0.35 * pulse),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withOpacity(0.14 + 0.16 * pulse),
                      blurRadius: 22 + 10 * pulse,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // moving light sweep
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-2 + 4 * _loop.value, -1),
                            end: Alignment(-1 + 4 * _loop.value, 1),
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -40 + 10 * math.sin(t),
                      top: -50,
                      child: _orb(170, Colors.white.withOpacity(0.06)),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -60 + 8 * math.cos(t),
                      child: _orb(120, gold.withOpacity(0.10)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 700;
                          final content = _buildContent(pulse);
                          final ring = _buildRing(pulse);

                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: content),
                                const SizedBox(width: 28),
                                ring,
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              content,
                              const SizedBox(height: 20),
                              Center(child: ring),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double pulse) {
    final gold = AppColors.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gold.withOpacity(0.55)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_rounded, size: 14, color: gold),
                  const SizedBox(width: 6),
                  const Text(
                    "REPORTS & ANALYTICS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const _LiveBadge(onDark: true),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          "Platform Insights",
          style: AppTextStyles.title.copyWith(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Approvals, funding and application activity — summarised live for quick, confident decisions.",
          style: AppTextStyles.subtitle.copyWith(
            color: Colors.white.withOpacity(0.82),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SpotKpi(
              icon: Icons.verified_rounded,
              label: "Approval rate",
              value: widget.approvalRate * 100,
              format: (v) => "${v.round()}%",
            ),
            _SpotKpi(
              icon: Icons.account_balance_wallet_rounded,
              label: "Funds listed",
              value: widget.totalFunds,
              format: (v) => "₹${_formatInr(v)}",
            ),
            _SpotKpi(
              icon: Icons.hourglass_top_rounded,
              label: "Awaiting review",
              value: widget.pending.toDouble(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Open Reports",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Transform.translate(
                offset: Offset(4 * pulse, 0),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRing(double pulse) {
    final gold = AppColors.secondary;

    return Container(
      width: 138,
      height: 138,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.10 + 0.14 * pulse),
            blurRadius: 18 + 10 * pulse,
            spreadRadius: 1 + 2 * pulse,
          ),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _unit(widget.approvalRate)),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(138, 138),
                painter: _RingPainter(
                  progress: progress,
                  color: gold,
                  track: Colors.white.withOpacity(0.14),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${(progress * 100).round()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    "approved",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpotKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String Function(double)? format;

  const _SpotKpi({
    required this.icon,
    required this.label,
    required this.value,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w800,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              format == null
                  ? _CountUp(value: value, style: valueStyle)
                  : _CountUp(value: value, style: valueStyle, format: format!),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 4
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

// ================================================================
// STATUS CARD (with animated share bar)
// ================================================================

class _StatusCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final int count;
  final int total;
  final Color color;
  final VoidCallback onTap;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.total,
    required this.color,
    required this.onTap,
  });

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final share = widget.total == 0 ? 0.0 : widget.count / widget.total;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(_hovering ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withOpacity(_hovering ? 0.40 : 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(_hovering ? 0.16 : 0.0),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, color: color, size: 27),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _CountUp(
                      value: widget.count.toDouble(),
                      style: AppTextStyles.title.copyWith(
                        fontSize: 24,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _unit(share)),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    return Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  "${(share * 100).round()}% of all applications",
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// RECENT APPLICATION TILE
// ================================================================

class _ApplicationTile extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ApplicationTile({
    required this.index,
    required this.data,
    required this.onTap,
  });

  @override
  State<_ApplicationTile> createState() => _ApplicationTileState();
}

class _ApplicationTileState extends State<_ApplicationTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final studentName = _firstNonEmpty(
      [widget.data["studentName"], widget.data["name"]],
      "Unknown Student",
    );
    final scholarshipTitle = _firstNonEmpty(
      [widget.data["scholarshipTitle"], widget.data["scholarshipName"]],
      "Scholarship",
    );
    final status = _normalizeStatus(widget.data["status"]);
    final color = _statusColor(status);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + widget.index * 120),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(32 * (1 - v), 0), child: child),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            transform: Matrix4.translationValues(_hovering ? 6 : 0, 0, 0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovering ? color.withOpacity(0.35) : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hovering ? 0.08 : 0.035),
                  blurRadius: _hovering ? 18 : 10,
                  offset: Offset(0, _hovering ? 8 : 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.10),
                  child: Text(
                    studentName[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scholarshipTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// RECENT SCHOLARSHIP TILE
// ================================================================

class _ScholarshipTile extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ScholarshipTile({
    required this.index,
    required this.data,
    required this.onTap,
  });

  @override
  State<_ScholarshipTile> createState() => _ScholarshipTileState();
}

class _ScholarshipTileState extends State<_ScholarshipTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final title = _firstNonEmpty(
      [widget.data["title"], widget.data["scholarshipTitle"]],
      "Scholarship",
    );
    final sponsorName = _firstNonEmpty([widget.data["sponsorName"]], "Sponsor");

    final rawAmount = widget.data["amount"];
    final numeric = _parseAmount(rawAmount);
    final amountText = numeric > 0
        ? "₹${_formatInr(numeric)}"
        : "₹${rawAmount?.toString() ?? '0'}";

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + widget.index * 120),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(32 * (1 - v), 0), child: child),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            transform: Matrix4.translationValues(_hovering ? 6 : 0, 0, 0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovering
                    ? Colors.orange.withOpacity(0.35)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hovering ? 0.08 : 0.035),
                  blurRadius: _hovering ? 18 : 10,
                  offset: Offset(0, _hovering ? 8 : 4),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  transform: Matrix4.identity()..scale(_hovering ? 1.08 : 1.0),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange.withOpacity(0.75)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sponsorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    amountText,
                    style: AppTextStyles.title.copyWith(
                      fontSize: 14.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// QUICK ACTION CARD (Reports is highlighted)
// ================================================================

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool highlighted;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final hi = widget.highlighted;
    final radius = BorderRadius.circular(18);

    final titleColor = hi ? Colors.white : AppColors.textPrimary;
    final subColor =
    hi ? Colors.white.withOpacity(0.8) : AppColors.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hi ? null : AppColors.card,
              gradient: hi
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, 0.28)!],
              )
                  : null,
              borderRadius: radius,
              border: Border.all(
                color: hi
                    ? AppColors.secondary.withOpacity(0.6)
                    : color.withOpacity(_hovering ? 0.40 : 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: hi
                      ? color.withOpacity(_hovering ? 0.45 : 0.30)
                      : Colors.black.withOpacity(_hovering ? 0.09 : 0.04),
                  blurRadius: _hovering ? 20 : 12,
                  offset: Offset(0, _hovering ? 10 : 5),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  transform: Matrix4.identity()..scale(_hovering ? 1.1 : 1.0),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: hi
                        ? null
                        : LinearGradient(
                      colors: [color, color.withOpacity(0.75)],
                    ),
                    color: hi ? Colors.white.withOpacity(0.18) : null,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.subtitle.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (hi) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: AppColors.secondary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 11,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(
                    _hovering ? 3 : 0,
                    0,
                    0,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: hi ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// EMPTY / LOADING
// ================================================================

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: AppColors.textSecondary.withOpacity(0.6),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}