import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'application_details_screen.dart';
import '../common/thank_you_sheet.dart';

// =========================================================
// HELPERS
// =========================================================

String _statusOf(Map<String, dynamic> d) {
  final s = d["status"]?.toString() ?? "Pending";
  return (s == "Approved" || s == "Rejected") ? s : "Pending";
}

Color _statusColor(String s) => s == "Approved"
    ? AppColors.success
    : s == "Rejected"
    ? AppColors.error
    : AppColors.warning;

IconData _statusIcon(String s) => s == "Approved"
    ? Icons.check_circle_rounded
    : s == "Rejected"
    ? Icons.cancel_rounded
    : Icons.access_time_rounded;

String _fmtDate(dynamic v) {
  if (v is! Timestamp) return "Date not available";
  final d = v.toDate();
  const m = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];
  return "${d.day} ${m[d.month - 1]} ${d.year}";
}

String _fmtAmount(dynamic v) {
  final s = (v ?? "").toString().trim();
  if (s.isEmpty) return "—";
  return s.startsWith("₹") ? s : "₹$s";
}

// =========================================================
// SCREEN
// =========================================================

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  String _filter = "All"; // All | Pending | Approved | Rejected

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: currentUser == null
          ? Center(
        child: Text("Please login again", style: AppTextStyles.subtitle),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("applications")
            .where("studentId", isEqualTo: currentUser.uid)
            .orderBy("appliedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final all = snapshot.data?.docs ?? [];

          int pending = 0, approved = 0, rejected = 0;
          for (final d in all) {
            final s = _statusOf(d.data() as Map<String, dynamic>);
            if (s == "Approved") {
              approved++;
            } else if (s == "Rejected") {
              rejected++;
            } else {
              pending++;
            }
          }

          return Column(
            children: [
              _Header(
                filter: _filter,
                total: all.length,
                pending: pending,
                approved: approved,
                rejected: rejected,
                onFilter: (f) => setState(() => _filter = f),
              ),
              Expanded(child: _content(context, snapshot, all)),
            ],
          );
        },
      ),
    );
  }

  Widget _content(
      BuildContext context,
      AsyncSnapshot<QuerySnapshot> snapshot,
      List<QueryDocumentSnapshot> all,
      ) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            "Error: ${snapshot.error}",
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.error),
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return _centered(
        ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _SkeletonCard(),
            _SkeletonCard(),
          ],
        ),
      );
    }

    final docs = all.where((d) {
      if (_filter == "All") return true;
      return _statusOf(d.data() as Map<String, dynamic>) == _filter;
    }).toList();

    if (docs.isEmpty) {
      return _EmptyState(
        title: all.isEmpty
            ? "No Applications Yet"
            : "No ${_filter.toLowerCase()} applications",
        subtitle: all.isEmpty
            ? "Apply for a scholarship and track it here."
            : "Try another filter above.",
      );
    }

    return _centered(
      ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;
          final applicationId = doc.id;

          return _StaggerIn(
            // new key per filter -> entrance animation replays on filter change
            key: ValueKey("$_filter-$applicationId"),
            delay: Duration(milliseconds: 80 * (index > 6 ? 6 : index)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _AppCard(
                data: data,
                applicationId: applicationId,
                onOpen: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApplicationDetailsScreen(
                        data: data,
                        applicationId: applicationId,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _centered(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: child,
    ),
  );
}

// =========================================================
// HEADER with animated filter tiles
// =========================================================

class _Header extends StatelessWidget {
  final String filter;
  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final ValueChanged<String> onFilter;

  const _Header({
    required this.filter,
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          12, MediaQuery.of(context).padding.top + 8, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.84)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "My Applications",
                          style: AppTextStyles.title.copyWith(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Track your scholarship journey",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.75)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: "All",
                        count: total,
                        icon: Icons.dashboard_rounded,
                        color: AppColors.primary,
                        selected: filter == "All",
                        onTap: () => onFilter("All"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        label: "Pending",
                        count: pending,
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                        selected: filter == "Pending",
                        onTap: () => onFilter("Pending"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        label: "Approved",
                        count: approved,
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        selected: filter == "Approved",
                        onTap: () => onFilter("Approved"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        label: "Rejected",
                        count: rejected,
                        icon: Icons.cancel_rounded,
                        color: AppColors.error,
                        selected: filter == "Rejected",
                        onTap: () => onFilter("Rejected"),
                      ),
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

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.secondary
                : Colors.white.withOpacity(0.15),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                icon,
                key: ValueKey(selected),
                size: 19,
                color: selected ? color : Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: count.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                "${v.round()}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primary : Colors.white,
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.textSecondary
                    : Colors.white.withOpacity(0.75),
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

class _AppCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String applicationId;
  final VoidCallback onOpen;

  const _AppCard({
    required this.data,
    required this.applicationId,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(data);
    final color = _statusColor(status);
    final title = data["scholarshipTitle"]?.toString() ?? "Scholarship";
    final college = (data["studentCollege"] ?? "").toString().trim();
    final docsVerified = data["documentsVerified"] == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- title + status ----------
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.75),
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              "Applied ${_fmtDate(data["appliedAt"])}",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: status),
                ],
              ),

              const SizedBox(height: 16),

              // ---------- amount + college ----------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary.withOpacity(0.16),
                      AppColors.secondary.withOpacity(0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border:
                  Border.all(color: AppColors.secondary.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Scholarship amount",
                            style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          _fmtAmount(data["amount"]),
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (college.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    college,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ---------- animated progress tracker ----------
              _Tracker(status: status, docsVerified: docsVerified),

              // ---------- thank-you (only after Approved) ----------
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: ThankYouButton(
                  applicationId: applicationId,
                  sponsorName: data["sponsorName"]?.toString(),
                ),
              ),

              const SizedBox(height: 14),

              // ---------- view details ----------
              _PressScale(
                onTap: onOpen,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.85),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility_outlined,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "View Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded,
                          color: AppColors.secondary, size: 18),
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

// =========================================================
// STATUS BADGE (pending = pulsing dot)
// =========================================================

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == "Pending")
            _Pulse(
              builder: (context, t) => Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5 * (1 - t)),
                      blurRadius: 4 + 8 * t,
                      spreadRadius: 1 + 3 * t,
                    ),
                  ],
                ),
              ),
            )
          else
            Icon(_statusIcon(status), size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// PROGRESS TRACKER: Applied -> Verified -> Decision
// =========================================================

enum _NodeState { done, current, pending, failed }

class _Tracker extends StatelessWidget {
  final String status;
  final bool docsVerified;
  const _Tracker({required this.status, required this.docsVerified});

  @override
  Widget build(BuildContext context) {
    final approved = status == "Approved";
    final rejected = status == "Rejected";
    final verified = docsVerified || approved;

    final s2 = verified
        ? _NodeState.done
        : (rejected ? _NodeState.pending : _NodeState.current);
    final s3 = approved
        ? _NodeState.done
        : rejected
        ? _NodeState.failed
        : (verified ? _NodeState.current : _NodeState.pending);
    final label3 = approved ? "Approved" : (rejected ? "Rejected" : "Decision");
    final icon3 = approved
        ? Icons.emoji_events_rounded
        : (rejected ? Icons.close_rounded : Icons.gavel_rounded);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _node(0, "Applied", _NodeState.done, Icons.send_rounded),
        _connector(verified, AppColors.success),
        _node(1, "Verified", s2, Icons.fact_check_rounded),
        _connector(approved || rejected,
            rejected ? AppColors.error : AppColors.success),
        _node(2, label3, s3, icon3),
      ],
    );
  }

  Widget _connector(bool filled, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: filled ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, v, _) => Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _node(int index, String label, _NodeState st, IconData icon) {
    Color bg;
    Widget inner;
    switch (st) {
      case _NodeState.done:
        bg = AppColors.success;
        inner = const Icon(Icons.check_rounded, color: Colors.white, size: 17);
        break;
      case _NodeState.failed:
        bg = AppColors.error;
        inner = Icon(icon, color: Colors.white, size: 16);
        break;
      case _NodeState.current:
        bg = AppColors.secondary;
        inner = Icon(icon, color: AppColors.primary, size: 16);
        break;
      case _NodeState.pending:
        bg = Colors.black.withOpacity(0.10);
        inner = Icon(icon, color: AppColors.textSecondary, size: 15);
        break;
    }

    Widget circle = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: inner,
    );

    if (st == _NodeState.current) {
      final base = circle;
      circle = _Pulse(
        builder: (context, t) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.30 + 0.45 * t),
                blurRadius: 6 + 10 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: base,
        ),
      );
    }

    return SizedBox(
      width: 70,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 450 + index * 200),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(
          scale: v.clamp(0.0, 1.3).toDouble(),
          child: child,
        ),
        child: Column(
          children: [
            circle,
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: st == _NodeState.pending
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// EMPTY STATE + SKELETON
// =========================================================

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(
                scale: v.clamp(0.0, 1.3).toDouble(),
                child: child,
              ),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(0.15),
                ),
                child: Icon(Icons.assignment_outlined,
                    size: 46, color: AppColors.secondary),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppTextStyles.title
                  .copyWith(fontSize: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle,
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.07),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      builder: (context, t) => Opacity(
        opacity: 0.55 + 0.45 * t,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
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
                      color: Colors.black.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_bar(170, 14), const SizedBox(height: 8), _bar(100, 10)],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _bar(double.infinity, 62),
              const SizedBox(height: 16),
              _bar(double.infinity, 40),
              const SizedBox(height: 14),
              _bar(double.infinity, 44),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// SMALL ANIMATION HELPERS
// =========================================================

/// Fade + slide-up entrance after [delay].
class _StaggerIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _StaggerIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn> {
  bool _go = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) setState(() => _go = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _go ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _go ? Offset.zero : const Offset(0, 0.10),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Looping 0..1..0 value for pulsing glows / dots.
class _Pulse extends StatefulWidget {
  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;
  const _Pulse({
    required this.builder,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          widget.builder(context, Curves.easeInOut.transform(_c.value)),
    );
  }
}

/// Shrinks slightly while pressed.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}