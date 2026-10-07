// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

import 'report_analytics.dart';
import 'report_detail_screen.dart';
import 'view_applications_screen.dart';

// ============================================================
// HELPERS
// ============================================================

const Color _navy = Color(0xFF1E3358);
const Color _amber = Color(0xFFF5A623);

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

String _field(
    Map<String, dynamic> data,
    List<String> keys, {
      String fallback = "N/A",
    }) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
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
  switch (status.toLowerCase()) {
    case "approved":
      return AppColors.success;
    case "rejected":
      return AppColors.error;
    default:
      return Colors.orange;
  }
}

IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case "approved":
      return Icons.check_circle_rounded;
    case "rejected":
      return Icons.cancel_rounded;
    default:
      return Icons.hourglass_top_rounded;
  }
}

void _openDetail(
    BuildContext context, {
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required Map<String, dynamic> data,
    }) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ReportDetailScreen(
        headerTitle: title,
        headerSubtitle: subtitle,
        icon: icon,
        color: color,
        data: data,
      ),
    ),
  );
}

// ============================================================
// DATA MODEL (computed from the 3 live Firestore streams)
// ============================================================

class _SponsorStat {
  final String name;
  final int scholarships;
  final int applications;
  final int approved;
  final double funds;

  const _SponsorStat({
    required this.name,
    required this.scholarships,
    required this.applications,
    required this.approved,
    required this.funds,
  });
}

class _SponsorAcc {
  final String name;
  int scholarships = 0;
  int applications = 0;
  int approved = 0;
  double funds = 0;

  _SponsorAcc(this.name);
}

class _ReportData {
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> sponsors;
  final List<Map<String, dynamic>> scholarships;
  final List<Map<String, dynamic>> applications;
  final int approved;
  final int pending;
  final int rejected;
  final double totalFunds;
  final List<_SponsorStat> topSponsors;
  final List<SponsorFund> sponsorFunds;

  const _ReportData({
    required this.students,
    required this.sponsors,
    required this.scholarships,
    required this.applications,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.totalFunds,
    required this.topSponsors,
    required this.sponsorFunds,
  });

  factory _ReportData.from({
    QuerySnapshot<Map<String, dynamic>>? users,
    QuerySnapshot<Map<String, dynamic>>? scholarships,
    QuerySnapshot<Map<String, dynamic>>? applications,
  }) {
    final userDocs =
        users?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final userList = userDocs.map((d) => d.data()).toList();

    List<Map<String, dynamic>> byRole(String role) {
      return userList.where((u) {
        return (u["role"]?.toString().trim().toLowerCase() ?? "") == role;
      }).toList();
    }

    // sponsor doc id -> display name
    final sponsorNameById = <String, String>{};
    for (final doc in userDocs) {
      final u = doc.data();
      if ((u["role"]?.toString().trim().toLowerCase() ?? "") == "sponsor") {
        sponsorNameById[doc.id] = _field(
          u,
          ["organizationName", "name", "companyName"],
          fallback: "Unknown Sponsor",
        );
      }
    }

    final schDocs = scholarships?.docs ??
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final scholarshipList = schDocs.map((d) => d.data()).toList();
    final applicationList = applications?.docs.map((d) => d.data()).toList() ??
        <Map<String, dynamic>>[];

    const sponsorIdKeys = ["sponsorId", "sponsorUid", "sponsor_id", "sponsorID"];

    final stats = <String, _SponsorAcc>{};
    final sponsorBySchId = <String, String>{};
    final sponsorBySchTitle = <String, String>{};
    double funds = 0;

    // ---- scholarships -> sponsor stats
    for (final doc in schDocs) {
      final data = doc.data();
      final amount = _parseAmount(data["amount"] ?? data["scholarshipAmount"]);
      funds += amount;

      var key = _field(data, sponsorIdKeys, fallback: "");
      final nameInDoc = _field(data, ["sponsorName", "sponsor"], fallback: "");
      if (key.isEmpty) key = nameInDoc;
      if (key.isEmpty) continue;

      final acc = stats.putIfAbsent(
        key,
            () => _SponsorAcc(
          sponsorNameById[key] ??
              (nameInDoc.isNotEmpty ? nameInDoc : "Unknown Sponsor"),
        ),
      );
      acc.scholarships++;
      acc.funds += amount;

      sponsorBySchId[doc.id] = key;
      final title =
      _field(data, ["title", "scholarshipName", "name"], fallback: "");
      if (title.isNotEmpty) sponsorBySchTitle[title] = key;
    }

    // ---- applications -> status counts + sponsor stats
    int approved = 0;
    int pending = 0;
    int rejected = 0;

    for (final a in applicationList) {
      final status = _normalizeStatus(a["status"]);
      switch (status) {
        case "Approved":
          approved++;
          break;
        case "Rejected":
          rejected++;
          break;
        default:
          pending++;
      }

      var key = _field(a, sponsorIdKeys, fallback: "");
      if (key.isEmpty) {
        final sid =
        _field(a, ["scholarshipId", "scholarship_id"], fallback: "");
        key = sponsorBySchId[sid] ?? "";
      }
      if (key.isEmpty) {
        final t = _field(
          a,
          ["scholarshipTitle", "scholarshipName", "title"],
          fallback: "",
        );
        key = sponsorBySchTitle[t] ?? "";
      }
      if (key.isEmpty) continue;

      final acc = stats.putIfAbsent(
        key,
            () => _SponsorAcc(sponsorNameById[key] ?? "Unknown Sponsor"),
      );
      acc.applications++;
      if (status == "Approved") acc.approved++;
    }

    final top = stats.values
        .map((acc) => _SponsorStat(
      name: acc.name,
      scholarships: acc.scholarships,
      applications: acc.applications,
      approved: acc.approved,
      funds: acc.funds,
    ))
        .toList()
      ..sort((x, y) {
        final byApps = y.applications.compareTo(x.applications);
        if (byApps != 0) return byApps;
        final bySch = y.scholarships.compareTo(x.scholarships);
        if (bySch != 0) return bySch;
        return x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });

    return _ReportData(
      students: byRole("student"),
      sponsors: byRole("sponsor"),
      scholarships: scholarshipList,
      applications: applicationList,
      approved: approved,
      pending: pending,
      rejected: rejected,
      totalFunds: funds,
      topSponsors: top.take(5).toList(),
      sponsorFunds: top
          .map((s) => SponsorFund(
        name: s.name,
        funds: s.funds,
        scholarships: s.scholarships,
      ))
          .toList(),
    );
  }

  ReportAnalyticsData toAnalytics() => ReportAnalyticsData.build(
    applications: applications,
    sponsorFunds: sponsorFunds,
    students: students.length,
    sponsors: sponsors.length,
    scholarships: scholarships.length,
    approved: approved,
    pending: pending,
    rejected: rejected,
    totalFunds: totalFunds,
  );

  int get totalApplications => applications.length;

  double get approvalRate =>
      totalApplications == 0 ? 0 : approved / totalApplications * 100;

  double get avgApplicationsPerScholarship => scholarships.isEmpty
      ? 0
      : totalApplications / scholarships.length;

  static int newThisWeek(List<Map<String, dynamic>> list) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    int n = 0;
    for (final data in list) {
      final createdAt = data["createdAt"] ??
          data["created_at"] ??
          data["timestamp"] ??
          data["dateCreated"];
      if (createdAt is Timestamp && createdAt.toDate().isAfter(weekAgo)) {
        n++;
      }
    }
    return n;
  }
}

// ============================================================
// SMALL ANIMATION HELPERS
// ============================================================

/// Fades and slides a child up into place, with a staggered start delay.
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _FadeSlideIn({
    required this.child,
    this.delayMs = 0,
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Lifts and scales a child slightly with a stronger shadow on hover.
class _HoverLift extends StatefulWidget {
  final Widget child;
  final double scale;
  final double radius;

  const _HoverLift({
    required this.child,
    this.scale = 1.02,
    this.radius = 20,
  });

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: _hovering
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pulsing "LIVE" badge for the header.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

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
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(.7 * _c.value),
                      blurRadius: 4 + 8 * _c.value,
                      spreadRadius: 1 + 2 * _c.value,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            "LIVE",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCREEN
// ============================================================

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _scholarshipsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _applicationsStream;

  final TextEditingController _search = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    _usersStream = db.collection("users").snapshots();
    _scholarshipsStream = db.collection("scholarships").snapshots();
    _applicationsStream = db.collection("applications").snapshots();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, usersSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _scholarshipsStream,
            builder: (context, schSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _applicationsStream,
                builder: (context, appSnap) {
                  final data = _ReportData.from(
                    users: usersSnap.data,
                    scholarships: schSnap.data,
                    applications: appSnap.data,
                  );

                  final loading =
                      (!usersSnap.hasData && !usersSnap.hasError) ||
                          (!schSnap.hasData && !schSnap.hasError) ||
                          (!appSnap.hasData && !appSnap.hasError);

                  return SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FadeSlideIn(child: _ReportsHeader()),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                            child: _content(context, data, loading),
                          ),
                        ],
                      ),
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

  // ============================================================
  // CONTENT
  // ============================================================

  bool _exporting = false;

  Future<void> _exportPdf(_ReportData d) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await exportReportPdf(d.toAnalytics());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not create PDF: $e")),
        );
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  Widget _content(BuildContext context, _ReportData d, bool loading) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        final summary = <Widget>[
          _FadeSlideIn(
            delayMs: 100,
            child: _SummaryCard(
              title: "Students",
              icon: Icons.people_alt_rounded,
              art: Icons.groups_rounded,
              art2: Icons.menu_book_rounded,
              color: Colors.blue,
              count: d.students.length,
              newCount: _ReportData.newThisWeek(d.students),
              phase: 0.0,
              // assetPath: "assets/images/students.png",
            ),
          ),
          _FadeSlideIn(
            delayMs: 180,
            child: _SummaryCard(
              title: "Sponsors",
              icon: Icons.business_rounded,
              art: Icons.apartment_rounded,
              art2: Icons.volunteer_activism_rounded,
              color: Colors.green,
              count: d.sponsors.length,
              newCount: _ReportData.newThisWeek(d.sponsors),
              phase: 0.2,
              // assetPath: "assets/images/sponsors.png",
            ),
          ),
          _FadeSlideIn(
            delayMs: 260,
            child: _SummaryCard(
              title: "Scholarships",
              icon: Icons.school_rounded,
              art: Icons.school_rounded,
              art2: Icons.workspace_premium_rounded,
              color: Colors.orange,
              count: d.scholarships.length,
              newCount: _ReportData.newThisWeek(d.scholarships),
              phase: 0.4,
              // assetPath: "assets/images/scholarships.png",
            ),
          ),
          _FadeSlideIn(
            delayMs: 340,
            child: _SummaryCard(
              title: "Applications",
              icon: Icons.assignment_rounded,
              art: Icons.description_rounded,
              art2: Icons.task_alt_rounded,
              color: Colors.purple,
              count: d.applications.length,
              newCount: _ReportData.newThisWeek(d.applications),
              phase: 0.6,
              // assetPath: "assets/images/applications.png",
            ),
          ),
        ];

        final kpis = <Widget>[
          _KpiTile(
            icon: Icons.trending_up_rounded,
            color: AppColors.success,
            label: "Approval Rate",
            end: d.approvalRate,
            format: (v) => "${v.round()}%",
          ),
          _KpiTile(
            icon: Icons.account_balance_wallet_rounded,
            color: _amber,
            label: "Total Scholarship Funds",
            end: d.totalFunds,
            format: (v) => "₹${_formatInr(v)}",
          ),
          _KpiTile(
            icon: Icons.insights_rounded,
            color: Colors.indigo,
            label: "Avg. Applications / Scholarship",
            end: d.avgApplicationsPerScholarship,
            format: (v) => v.toStringAsFixed(1),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: (loading || _exporting) ? null : () => _exportPdf(d),
                icon: _exporting
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(_exporting ? "Preparing..." : "Download PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  minimumSize: const Size(0, 46),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),

            _cardGrid(summary, wide ? 4 : 2),

            const SizedBox(height: 28),

            const _SectionHeading(
              title: "Key Insights",
              subtitle: "Calculated live from your platform data",
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              delayMs: 420,
              child: wide
                  ? _cardGrid(kpis, 3)
                  : Column(
                children: [
                  for (int i = 0; i < kpis.length; i++) ...[
                    kpis[i],
                    if (i != kpis.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            const _SectionHeading(
              title: "Application Status",
              subtitle: "Tap a status to open those applications",
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              delayMs: 500,
              child: _statusPanel(context, d, wide),
            ),

            const SizedBox(height: 28),

            const _SectionHeading(
              title: "Analytics",
              subtitle: "Applications trend, popular scholarships and sponsor funding",
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              delayMs: 540,
              child: ReportAnalyticsSection(data: d.toAnalytics()),
            ),

            const SizedBox(height: 28),

            const _SectionHeading(
              title: "Top Sponsors",
              subtitle: "Rated by applications their scholarships received",
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              delayMs: 580,
              child: _topSponsorsPanel(d),
            ),

            const SizedBox(height: 28),

            const _SectionHeading(
              title: "All Records",
              subtitle: "Tap any entry to view full details",
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              delayMs: 660,
              child: _recordsSection(context, d, loading),
            ),
          ],
        );
      },
    );
  }

  Widget _cardGrid(List<Widget> items, int columns, {double gap = 14}) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += columns) {
      final chunk = items.skip(i).take(columns).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int j = 0; j < columns; j++) ...[
              if (j > 0) SizedBox(width: gap),
              Expanded(
                child: j < chunk.length ? chunk[j] : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (i + columns < items.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }

  // ============================================================
  // STATUS PANEL (donut + rows)
  // ============================================================

  Widget _statusPanel(BuildContext context, _ReportData d, bool wide) {
    final total = d.totalApplications;
    double share(int v) => total == 0 ? 0 : v / total;

    void openFilter(String filter) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewApplicationsScreen(initialFilter: filter),
        ),
      );
    }

    final rows = Column(
      children: [
        _StatusRow(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          label: "Approved",
          value: d.approved,
          share: share(d.approved),
          onTap: () => openFilter("Approved"),
        ),
        const SizedBox(height: 12),
        _StatusRow(
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
          label: "Pending",
          value: d.pending,
          share: share(d.pending),
          onTap: () => openFilter("Pending"),
        ),
        const SizedBox(height: 12),
        _StatusRow(
          icon: Icons.cancel_rounded,
          color: AppColors.error,
          label: "Rejected",
          value: d.rejected,
          share: share(d.rejected),
          onTap: () => openFilter("Rejected"),
        ),
      ],
    );

    final donut = _StatusDonut(
      approved: d.approved,
      pending: d.pending,
      rejected: d.rejected,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: wide
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          donut,
          const SizedBox(width: 32),
          Expanded(child: rows),
        ],
      )
          : Column(
        children: [
          donut,
          const SizedBox(height: 22),
          rows,
        ],
      ),
    );
  }

  // ============================================================
  // TOP SPONSORS
  // ============================================================

  Widget _topSponsorsPanel(_ReportData d) {
    final top = d.topSponsors;

    if (top.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            "No sponsor activity yet",
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final maxApps = top.first.applications;

    return Column(
      children: [
        for (int i = 0; i < top.length; i++) ...[
          _FadeSlideIn(
            delayMs: i * 100,
            child: _SponsorTile(
              rank: i + 1,
              stat: top[i],
              stars: top[i].applications == 0 || maxApps == 0
                  ? 0
                  : (top[i].applications / maxApps * 5).round().clamp(1, 5).toInt(),
              delayMs: i * 100,
            ),
          ),
          if (i != top.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ============================================================
  // ALL RECORDS (tabs + search)
  // ============================================================

  Widget _recordsSection(BuildContext context, _ReportData d, bool loading) {
    final narrow = MediaQuery.of(context).size.width < 600;

    return DefaultTabController(
      length: 4,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                isScrollable: narrow,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(text: "Students (${d.students.length})"),
                  Tab(text: "Sponsors (${d.sponsors.length})"),
                  Tab(text: "Scholarships (${d.scholarships.length})"),
                  Tab(text: "Applications (${d.applications.length})"),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: "Search records...",
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = "");
                    },
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            SizedBox(
              height: 480,
              child: TabBarView(
                children: [
                  _studentsList(context, d, loading),
                  _sponsorsList(context, d, loading),
                  _scholarshipsList(context, d, loading),
                  _applicationsList(context, d, loading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _recordsList({
    required bool loading,
    required List<Map<String, dynamic>> items,
    required String emptyText,
    required String Function(Map<String, dynamic>) searchText,
    required Widget Function(Map<String, dynamic>) tileBuilder,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? items
        : items.where((d) => searchText(d).toLowerCase().contains(q)).toList();

    if (list.isEmpty) {
      return _emptyState(q.isEmpty ? emptyText : 'No results for "$_query"');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _FadeSlideIn(
          delayMs: math.min(index, 10) * 40,
          child: tileBuilder(list[index]),
        );
      },
    );
  }

  Widget _studentsList(BuildContext context, _ReportData d, bool loading) {
    return _recordsList(
      loading: loading,
      items: d.students,
      emptyText: "No students found",
      searchText: (data) =>
      "${_field(data, ["name", "fullName", "studentName"])} "
          "${_field(data, ["email"])} "
          "${_field(data, ["phone", "phoneNumber", "mobile"])}",
      tileBuilder: (data) {
        final name = _field(data, ["name", "fullName", "studentName"]);
        final email = _field(data, ["email"]);
        final phone = _field(data, ["phone", "phoneNumber", "mobile"]);

        return _RecordTile(
          icon: Icons.person_rounded,
          color: Colors.blue,
          title: name,
          subtitle: "$email  •  $phone",
          onTap: () => _openDetail(
            context,
            title: name,
            subtitle: "Student",
            icon: Icons.person_rounded,
            color: Colors.blue,
            data: data,
          ),
        );
      },
    );
  }

  Widget _sponsorsList(BuildContext context, _ReportData d, bool loading) {
    return _recordsList(
      loading: loading,
      items: d.sponsors,
      emptyText: "No sponsors found",
      searchText: (data) =>
      "${_field(data, ["name", "organizationName", "companyName"])} "
          "${_field(data, ["email"])} "
          "${_field(data, ["phone", "phoneNumber", "mobile"])}",
      tileBuilder: (data) {
        final name = _field(data, ["name", "organizationName", "companyName"]);
        final email = _field(data, ["email"]);
        final phone = _field(data, ["phone", "phoneNumber", "mobile"]);

        return _RecordTile(
          icon: Icons.business_rounded,
          color: Colors.green,
          title: name,
          subtitle: "$email  •  $phone",
          onTap: () => _openDetail(
            context,
            title: name,
            subtitle: "Sponsor",
            icon: Icons.business_rounded,
            color: Colors.green,
            data: data,
          ),
        );
      },
    );
  }

  Widget _scholarshipsList(BuildContext context, _ReportData d, bool loading) {
    return _recordsList(
      loading: loading,
      items: d.scholarships,
      emptyText: "No scholarships found",
      searchText: (data) =>
      "${_field(data, ["title", "scholarshipName", "name"])} "
          "${_field(data, ["sponsorName", "sponsor"])}",
      tileBuilder: (data) {
        final title = _field(data, ["title", "scholarshipName", "name"]);
        final amount = _field(data, ["amount", "scholarshipAmount"]);
        final sponsorName = _field(data, ["sponsorName", "sponsor"]);

        return _RecordTile(
          icon: Icons.school_rounded,
          color: Colors.orange,
          title: title,
          subtitle: "Sponsor: $sponsorName",
          trailing: "₹$amount",
          onTap: () => _openDetail(
            context,
            title: title,
            subtitle: "Scholarship",
            icon: Icons.school_rounded,
            color: Colors.orange,
            data: data,
          ),
        );
      },
    );
  }

  Widget _applicationsList(BuildContext context, _ReportData d, bool loading) {
    return _recordsList(
      loading: loading,
      items: d.applications,
      emptyText: "No applications found",
      searchText: (data) =>
      "${_field(data, ["studentName", "applicantName", "name"])} "
          "${_field(data, ["scholarshipTitle", "scholarshipName", "title"])} "
          "${_normalizeStatus(data["status"])}",
      tileBuilder: (data) {
        final studentName = _field(
          data,
          ["studentName", "applicantName", "name"],
          fallback: "Unknown Student",
        );
        final scholarshipTitle = _field(
          data,
          ["scholarshipTitle", "scholarshipName", "title"],
          fallback: "Unknown Scholarship",
        );
        final status = _normalizeStatus(data["status"]);
        final color = _statusColor(status);
        final icon = _statusIcon(status);

        return _RecordTile(
          icon: icon,
          color: color,
          title: studentName,
          subtitle: "Applied for: $scholarshipTitle",
          statusLabel: status,
          statusColor: color,
          onTap: () => _openDetail(
            context,
            title: studentName,
            subtitle: "Application — $status",
            icon: icon,
            color: color,
            data: data,
          ),
        );
      },
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF34558F)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.06),
              ),
            ),
          ),
          Positioned(
            right: 90,
            bottom: -60,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _amber.withOpacity(.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 20, 26),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Reports & Analytics",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Live overview of the scholarship platform",
                        style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const _LiveBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeading({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: subtitle == null ? 20 : 38,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_amber, _navy],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.title.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SUMMARY CARD (count-up number)
// ============================================================

class _SummaryCard extends StatefulWidget {
  final String title;
  final IconData icon; // small icon in the chip
  final IconData art; // big background illustration
  final IconData art2; // small floating background icon
  final Color color;
  final int count;
  final int newCount;
  final double phase; // 0..1, so the 4 cards don't move in sync

  /// Optional: your own logo / image (example: "assets/images/students.png").
  /// Agar image illa na, automatic ah icon art kaatum.
  final String? assetPath;

  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.art,
    required this.art2,
    required this.color,
    required this.count,
    required this.newCount,
    this.phase = 0,
    this.assetPath,
  });

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _artwork(Color color) {
    final path = widget.assetPath;
    final fallback = Icon(widget.art, size: 112, color: color.withOpacity(.16));

    if (path == null) return fallback;

    return Opacity(
      opacity: .30,
      child: Image.asset(
        path,
        width: 112,
        height: 112,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;

    // content (built once, not on every animation frame)
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final r = ((_c.value + widget.phase) * 2) % 1.0;
            return SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // pulsing ring
                  Transform.scale(
                    scale: 1 + 0.55 * r,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity((1 - r) * .45),
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withOpacity(.32), color.withOpacity(.14)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: color, size: 23),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: widget.count.toDouble()),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            return Text(
              "${v.round()}",
              style: AppTextStyles.title.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          widget.title,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: widget.newCount > 0
              ? Container(
            key: const ValueKey("new"),
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "${widget.newCount} new this week",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          )
              : const SizedBox(key: ValueKey("none"), height: 22),
        ),
      ],
    );

    return _HoverLift(
      scale: 1.03,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(minHeight: 172),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(.18), color.withOpacity(.05)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.28), width: 1.2),
        ),
        child: AnimatedBuilder(
          animation: _c,
          child: content,
          builder: (context, child) {
            final t = (_c.value + widget.phase) % 1.0;
            final bob = math.sin(t * 2 * math.pi);
            final bob2 = math.sin((t + .5) * 2 * math.pi);
            final twinkle1 = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2);
            final twinkle2 = 0.5 + 0.5 * math.sin((t + .3) * 2 * math.pi * 2);

            // shimmer sweep (runs during the first part of every cycle)
            final sweepT = t < .45 ? t / .45 : -1.0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // concentric rings
                Positioned(
                  right: -36,
                  bottom: -36,
                  child: Transform.scale(
                    scale: 1 + 0.04 * bob,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity(.14),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -70,
                  bottom: -70,
                  child: Transform.scale(
                    scale: 1 + 0.04 * bob2,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(.05),
                      ),
                    ),
                  ),
                ),

                // twinkling dots
                Positioned(
                  right: 46,
                  top: 6,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(.15 + .35 * twinkle1),
                    ),
                  ),
                ),
                Positioned(
                  right: 120,
                  bottom: 30,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(.15 + .35 * twinkle2),
                    ),
                  ),
                ),

                // small floating secondary icon
                Positioned(
                  right: 128,
                  top: 10,
                  child: Transform.translate(
                    offset: Offset(0, bob2 * 5),
                    child: Transform.rotate(
                      angle: bob2 * 0.12,
                      child: Icon(
                        widget.art2,
                        size: 30,
                        color: color.withOpacity(.22),
                      ),
                    ),
                  ),
                ),

                // main artwork (pops in, then floats)
                Positioned(
                  right: 8,
                  bottom: 2,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutBack,
                    builder: (context, pop, art) {
                      return Transform.scale(
                        scale: pop,
                        child: Transform.translate(
                          offset: Offset(0, bob * 6),
                          child: Transform.rotate(
                            angle: bob * 0.05,
                            child: art,
                          ),
                        ),
                      );
                    },
                    child: _artwork(color),
                  ),
                ),

                // shimmer sweep
                if (sweepT >= 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final w = box.maxWidth;
                          final x = -0.3 * w + (1.4 * w) * sweepT;
                          return Transform.translate(
                            offset: Offset(x, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Transform(
                                transform: Matrix4.skewX(-0.35),
                                child: Container(
                                  width: w * 0.22,
                                  height: box.maxHeight,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0),
                                        Colors.white.withOpacity(.28),
                                        Colors.white.withOpacity(0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // text content on top
                child!,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// KPI TILE
// ============================================================

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double end;
  final String Function(double) format;

  const _KpiTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.end,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      scale: 1.02,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(.7)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: end),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) {
                      return Text(
                        format(v),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STATUS DONUT + ROWS
// ============================================================

class _StatusDonut extends StatelessWidget {
  final int approved;
  final int pending;
  final int rejected;

  const _StatusDonut({
    required this.approved,
    required this.pending,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final total = approved + pending + rejected;

    return SizedBox(
      width: 190,
      height: 190,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(190, 190),
                painter: _DonutPainter(
                  values: [
                    approved.toDouble(),
                    pending.toDouble(),
                    rejected.toDouble(),
                  ],
                  colors: [AppColors.success, Colors.orange, AppColors.error],
                  progress: p,
                  track: AppColors.textSecondary.withOpacity(.10),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${(total * p).round()}",
                    style: AppTextStyles.title.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Applications",
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double progress;
  final Color track;

  _DonutPainter({
    required this.values,
    required this.colors,
    required this.progress,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;

    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    const gap = 0.06;
    var start = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;

      final sweep = values[i] / total * 2 * math.pi * progress;
      final drawn = sweep > gap ? sweep - gap : sweep;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = colors[i];

      canvas.drawArc(rect, start + gap / 2, drawn, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.progress != progress ||
        old.values[0] != values[0] ||
        old.values[1] != values[1] ||
        old.values[2] != values[2];
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final double share; // 0..1
  final VoidCallback onTap;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.share,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      scale: 1.015,
      radius: 16,
      child: Material(
        color: color.withOpacity(.07),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(.22), width: 1.2),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withOpacity(.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: value.toDouble()),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) {
                        return Text(
                          "${v.round()}",
                          style: AppTextStyles.title.copyWith(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${(share * 100).round()}%",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary.withOpacity(.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: share),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    return Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: color.withOpacity(.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v.clamp(0.0, 1.0),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TOP SCHOLARSHIP RANK BAR
// ============================================================

class _SponsorTile extends StatelessWidget {
  final int rank;
  final _SponsorStat stat;
  final int stars; // 0..5
  final int delayMs;

  const _SponsorTile({
    required this.rank,
    required this.stat,
    required this.stars,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    final top = rank == 1;

    final titleColor = top ? Colors.white : AppColors.textPrimary;
    final subColor =
    top ? Colors.white.withOpacity(.78) : AppColors.textSecondary;
    final initial =
    stat.name.trim().isEmpty ? "?" : stat.name.trim()[0].toUpperCase();

    final details = <String>[
      stat.scholarships == 1
          ? "1 scholarship"
          : "${stat.scholarships} scholarships",
      if (stat.funds > 0) "₹${_formatInr(stat.funds)} funded",
      if (stat.approved > 0) "${stat.approved} approved",
    ];

    return _HoverLift(
      scale: 1.01,
      radius: 18,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: top
              ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_navy, Color(0xFF34558F)],
          )
              : null,
          color: top ? null : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: top
              ? null
              : Border.all(color: AppColors.textSecondary.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              color: top
                  ? _navy.withOpacity(.22)
                  : Colors.black.withOpacity(.03),
              blurRadius: top ? 16 : 10,
              offset: Offset(0, top ? 8 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: top
                    ? Colors.white.withOpacity(.16)
                    : _navy.withOpacity(.07),
              ),
              child: Text(
                initial,
                style: TextStyle(
                  color: top ? Colors.white : _navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          stat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (top) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _amber.withOpacity(.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "TOP SPONSOR",
                            style: TextStyle(
                              color: _amber,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details.join("  •  "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Tooltip(
                  message: "Popularity based on applications received",
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < 5; i++)
                        _PopStar(
                          filled: i < stars,
                          delayMs: delayMs + i * 110,
                          emptyColor: top
                              ? Colors.white.withOpacity(.35)
                              : AppColors.textSecondary.withOpacity(.35),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stat.applications == 1
                      ? "1 application"
                      : "${stat.applications} applications",
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11.5,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One star that pops in (scale animation) after a small delay.
class _PopStar extends StatefulWidget {
  final bool filled;
  final int delayMs;
  final Color emptyColor;

  const _PopStar({
    required this.filled,
    required this.delayMs,
    required this.emptyColor,
  });

  @override
  State<_PopStar> createState() => _PopStarState();
}

class _PopStarState extends State<_PopStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);

    Future.delayed(Duration(milliseconds: 500 + widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        widget.filled ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 19,
        color: widget.filled ? _amber : widget.emptyColor,
      ),
    );
  }
}

// ============================================================
// RECORD TILE
// ============================================================

class _RecordTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailing;
  final String? statusLabel;
  final Color? statusColor;

  const _RecordTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.statusLabel,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _HoverLift(
        scale: 1.015,
        radius: 18,
        child: Material(
          color: AppColors.background,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color.withOpacity(.18),
                                  color.withOpacity(.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(icon, color: color, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
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
                          if (statusLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: (statusColor ?? AppColors.primary)
                                    .withOpacity(.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor ?? AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                          if (trailing != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              trailing!,
                              style: AppTextStyles.title.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary.withOpacity(.4),
                          ),
                        ],
                      ),
                    ),
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