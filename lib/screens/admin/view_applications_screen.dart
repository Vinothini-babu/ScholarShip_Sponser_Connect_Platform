// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'admin_status_section.dart';

// ============================================================
// HELPERS
// ============================================================

const Color _navy = Color(0xFF1E3358);
const Color _coral = Color(0xFFEF6343);

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

String _amountText(dynamic raw) {
  final n = _parseAmount(raw);
  if (n > 0) return _formatInr(n);
  return raw?.toString() ?? "0";
}

int _millis(dynamic v) => v is Timestamp ? v.millisecondsSinceEpoch : 0;

String _formatDate(Timestamp t) {
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  final d = t.toDate();
  return "${d.day} ${months[d.month - 1]} ${d.year}";
}

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
  switch (status.toLowerCase()) {
    case "approved":
      return Colors.green;
    case "rejected":
      return Colors.red;
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

Widget _topLeftLayout(Widget? current, List<Widget> previous) {
  return Stack(
    alignment: Alignment.topLeft,
    children: [...previous, if (current != null) current],
  );
}

Widget _fadeSlide(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

// ============================================================
// SCREEN
// ============================================================

class ViewApplicationsScreen extends StatefulWidget {
  final String initialFilter;

  const ViewApplicationsScreen({
    super.key,
    this.initialFilter = "All",
  });

  @override
  State<ViewApplicationsScreen> createState() =>
      _ViewApplicationsScreenState();
}

class _ViewApplicationsScreenState extends State<ViewApplicationsScreen> {
  late String _selectedFilter;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  /// ids currently animating out before the Firestore delete
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();

    switch (widget.initialFilter.toLowerCase()) {
      case "pending":
        _selectedFilter = "Pending";
        break;
      case "approved":
        _selectedFilter = "Approved";
        break;
      case "rejected":
        _selectedFilter = "Rejected";
        break;
      default:
        _selectedFilter = "All";
    }

    _stream = FirebaseFirestore.instance.collection("applications").snapshots();
  }

  // ============================================================
  // GET SPONSOR NAME
  // ============================================================

  Future<String> _getSponsorName(String sponsorId) async {
    if (sponsorId.isEmpty) {
      return "Unknown Sponsor";
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(sponsorId)
          .get();

      if (doc.exists) {
        final data = doc.data();

        if (data != null) {
          final name = data["name"]?.toString();
          final organizationName = data["organizationName"]?.toString();

          if (organizationName != null && organizationName.isNotEmpty) {
            return organizationName;
          }

          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      }

      return "Unknown Sponsor";
    } catch (e) {
      debugPrint("Sponsor fetch error: $e");
      return "Unknown Sponsor";
    }
  }

  // ============================================================
  // DELETE APPLICATION
  // ============================================================

  Future<void> _deleteApplication(
      BuildContext context,
      String applicationId,
      ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("Delete Application")),
            ],
          ),
          content: const Text(
            "Are you sure you want to delete this application?",
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    // let the card animate out first
    setState(() => _removing.add(applicationId));
    await Future.delayed(const Duration(milliseconds: 380));

    try {
      await FirebaseFirestore.instance
          .collection("applications")
          .doc(applicationId)
          .delete();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Text("Application deleted successfully"),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _removing.remove(applicationId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text("Failed to delete application: $e"),
        ),
      );
    }
  }

  // ============================================================
  // VIEW APPLICATION DETAILS
  // ============================================================

  void _showApplicationDetails(
      BuildContext context,
      Map<String, dynamic> data,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _DetailsDialog(data: data),
    );
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterApplications(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    if (_selectedFilter == "All") {
      return docs;
    }

    return docs.where((doc) {
      return _normalizeStatus(doc.data()["status"]) == _selectedFilter;
    }).toList();
  }

  String _pageTitle() {
    switch (_selectedFilter) {
      case "Pending":
        return "Pending Applications";
      case "Approved":
        return "Approved Applications";
      case "Rejected":
        return "Rejected Applications";
      default:
        return "Student Applications";
    }
  }

  String _countText(int count) {
    if (_selectedFilter == "All") {
      return "$count applications received";
    }

    return "$count ${_selectedFilter.toLowerCase()} applications found";
  }

  Color _filterColor(String filter) {
    switch (filter) {
      case "Pending":
        return Colors.orange;
      case "Approved":
        return Colors.green;
      case "Rejected":
        return Colors.red;
      default:
        return AppColors.secondary;
    }
  }

  IconData _filterIcon(String filter) {
    switch (filter) {
      case "Pending":
        return Icons.hourglass_top_rounded;
      case "Approved":
        return Icons.verified_rounded;
      case "Rejected":
        return Icons.cancel_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;
          final hasError = snapshot.hasError;

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [
            ...?snapshot.data?.docs,
          ];

          // newest first
          allDocs.sort(
                (a, b) => _millis(b.data()["appliedAt"])
                .compareTo(_millis(a.data()["appliedAt"])),
          );

          int pending = 0;
          int approved = 0;
          int rejected = 0;
          for (final d in allDocs) {
            final s = _normalizeStatus(d.data()["status"]);
            if (s == "Approved") {
              approved++;
            } else if (s == "Rejected") {
              rejected++;
            } else {
              pending++;
            }
          }

          final filteredDocs = _filterApplications(allDocs);

          final subtitle =
          loading ? "Loading applications..." : _countText(filteredDocs.length);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(
                  title: _pageTitle(),
                  subtitle: subtitle,
                  accent: _filterColor(_selectedFilter),
                  icon: _filterIcon(_selectedFilter),
                  onBack: () => Navigator.pop(context),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------------- FILTER PILLS ----------------
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final f in const [
                              "All",
                              "Pending",
                              "Approved",
                              "Rejected",
                            ])
                              _FilterPill(
                                label: f,
                                count: f == "All"
                                    ? allDocs.length
                                    : f == "Pending"
                                    ? pending
                                    : f == "Approved"
                                    ? approved
                                    : rejected,
                                icon: _filterIcon(f),
                                color: f == "All"
                                    ? AppColors.primary
                                    : _filterColor(f),
                                selected: _selectedFilter == f,
                                onTap: () =>
                                    setState(() => _selectedFilter = f),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ---------------- CONTENT ----------------
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: _topLeftLayout,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: KeyedSubtree(
                          key: ValueKey(
                            "$_selectedFilter|$loading|$hasError|${filteredDocs.isEmpty}",
                          ),
                          child: _buildContent(
                            context,
                            loading: loading,
                            error: snapshot.error,
                            docs: filteredDocs,
                          ),
                        ),
                      ),
                    ],
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
      BuildContext context, {
        required bool loading,
        required Object? error,
        required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      }) {
    if (loading) {
      return const _SkeletonList();
    }

    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              "Something went wrong.\n\n$error",
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (docs.isEmpty) {
      return _EmptyState(
        icon: _filterIcon(_selectedFilter),
        message: _emptyMessage(),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < docs.length; i++)
          _ApplicationCard(
            key: ValueKey(docs[i].id),
            index: i,
            data: docs[i].data(),
            removing: _removing.contains(docs[i].id),
            fetchSponsor: _getSponsorName,
            onView: (data) => _showApplicationDetails(context, data),
            onDelete: () => _deleteApplication(context, docs[i].id),
          ),
      ],
    );
  }

  String _emptyMessage() {
    switch (_selectedFilter) {
      case "Pending":
        return "No pending applications found";
      case "Approved":
        return "No approved applications found";
      case "Rejected":
        return "No rejected applications found";
      default:
        return "No applications found";
    }
  }
}

// ============================================================
// PAGE HEADER (animated gradient hero)
// ============================================================

class _PageHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onBack;

  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onBack,
  });

  @override
  State<_PageHeader> createState() => _PageHeaderState();
}

class _PageHeaderState extends State<_PageHeader>
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
        double? bottom,
        double size = 4,
      }) {
    final o = 0.15 + 0.5 * (0.5 + 0.5 * math.sin(t * 2 + phase));
    return Positioned(
      right: right,
      top: top,
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
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.accent),
      duration: const Duration(milliseconds: 500),
      builder: (context, animatedAccent, _) {
        final accent = animatedAccent ?? widget.accent;

        return AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            final t = 2 * math.pi * _loop.value;
            final drift = math.sin(t);
            final drift2 = math.cos(t);
            final pulse = 0.5 + 0.5 * math.sin(t * 3);

            return Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + 0.5 * drift, -1),
                  end: Alignment(1, 1 + 0.4 * drift2),
                  colors: [
                    AppColors.primary,
                    Color.lerp(AppColors.primary, accent, 0.22)!,
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
                        color: accent.withOpacity(0.14),
                      ),
                    ),
                  ),
                  _twinkle(t, 0, right: 100, top: 40),
                  _twinkle(t, 1.6, right: 230, top: 80, size: 3),
                  _twinkle(t, 3.1, right: 60, bottom: 24, size: 5),

                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // top bar
                          Row(
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
                                  tooltip: "Back",
                                  onPressed: widget.onBack,
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "View Applications",
                                style: AppTextStyles.subtitle.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent
                                          .withOpacity(0.55 + 0.45 * pulse),
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent
                                            .withOpacity(0.20 + 0.30 * pulse),
                                        blurRadius: 10 + 12 * pulse,
                                        spreadRadius: 1 + 2 * pulse,
                                      ),
                                    ],
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, anim) =>
                                        ScaleTransition(
                                          scale: anim,
                                          child: FadeTransition(
                                            opacity: anim,
                                            child: child,
                                          ),
                                        ),
                                    child: Icon(
                                      widget.icon,
                                      key: ValueKey(widget.icon),
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      AnimatedSwitcher(
                                        duration:
                                        const Duration(milliseconds: 320),
                                        layoutBuilder: _topLeftLayout,
                                        transitionBuilder: _fadeSlide,
                                        child: Text(
                                          widget.title,
                                          key: ValueKey(widget.title),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.title.copyWith(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.13),
                                          borderRadius:
                                          BorderRadius.circular(20),
                                          border: Border.all(
                                            color: accent.withOpacity(0.5),
                                          ),
                                        ),
                                        child: AnimatedSwitcher(
                                          duration:
                                          const Duration(milliseconds: 320),
                                          layoutBuilder: _topLeftLayout,
                                          transitionBuilder: _fadeSlide,
                                          child: Text(
                                            widget.subtitle,
                                            key: ValueKey(widget.subtitle),
                                            style:
                                            AppTextStyles.subtitle.copyWith(
                                              color: Colors.white
                                                  .withOpacity(0.92),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// FILTER PILL
// ============================================================

class _FilterPill extends StatefulWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final sel = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering && !sel ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: sel
                  ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                  : null,
              color: sel ? null : AppColors.card,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: sel
                    ? Colors.transparent
                    : color.withOpacity(_hovering ? 0.5 : 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: sel
                      ? color.withOpacity(0.35)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: sel ? 14 : 8,
                  offset: Offset(0, sel ? 6 : 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: sel ? Colors.white : color,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: sel ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white.withOpacity(0.24)
                        : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${widget.count}",
                    style: TextStyle(
                      color: sel ? Colors.white : color,
                      fontSize: 11.5,
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

// ============================================================
// APPLICATION CARD
// ============================================================

class _ApplicationCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final bool removing;
  final Future<String> Function(String) fetchSponsor;
  final void Function(Map<String, dynamic>) onView;
  final VoidCallback onDelete;

  const _ApplicationCard({
    super.key,
    required this.index,
    required this.data,
    required this.removing,
    required this.fetchSponsor,
    required this.onView,
    required this.onDelete,
  });

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  bool _hovering = false;
  late final Future<String> _sponsorFuture;

  @override
  void initState() {
    super.initState();

    final sponsorName = widget.data["sponsorName"]?.toString();
    final sponsorId = widget.data["sponsorId"]?.toString() ??
        widget.data["sponsorID"]?.toString() ??
        "";

    _sponsorFuture = (sponsorName != null && sponsorName.isNotEmpty)
        ? Future.value(sponsorName)
        : widget.fetchSponsor(sponsorId);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final studentName = _firstNonEmpty(
      [data["studentName"], data["name"]],
      "Unknown Student",
    );
    final scholarshipTitle = _firstNonEmpty(
      [data["scholarshipTitle"], data["scholarshipName"]],
      "Scholarship",
    );
    final status = _normalizeStatus(data["status"]);
    final color = _statusColor(status);
    final amount = _amountText(data["amount"]);
    final appliedAt = data["appliedAt"];
    final appliedText = appliedAt is Timestamp ? _formatDate(appliedAt) : null;

    final entranceMs = 450 + math.min(widget.index, 8) * 90;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: widget.removing ? 0.0 : 1.0),
      duration: Duration(milliseconds: widget.removing ? 320 : entranceMs),
      curve: widget.removing ? Curves.easeInCubic : Curves.easeOutCubic,
      builder: (context, v, child) {
        return ClipRect(
          clipBehavior: widget.removing ? Clip.hardEdge : Clip.none,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: widget.removing ? v : 1.0,
            child: Opacity(
              opacity: v,
              child: Transform.translate(
                offset: widget.removing
                    ? Offset(-60 * (1 - v), 0)
                    : Offset(0, 24 * (1 - v)),
                child: child,
              ),
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 16),
          transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovering ? color.withOpacity(0.30) : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovering
                    ? color.withOpacity(0.14)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _hovering ? 22 : 12,
                offset: Offset(0, _hovering ? 10 : 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              // status accent strip
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: color),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.16),
                                AppColors.primary.withOpacity(0.06),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              studentName[0].toUpperCase(),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
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
                                style: AppTextStyles.title.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.school_rounded,
                                text: scholarshipTitle,
                              ),
                              const SizedBox(height: 7),
                              FutureBuilder<String>(
                                future: _sponsorFuture,
                                builder: (context, snap) {
                                  return _InfoRow(
                                    icon: Icons.business_rounded,
                                    text: snap.data ??
                                        data["sponsorName"]?.toString() ??
                                        "Loading...",
                                  );
                                },
                              ),
                              const SizedBox(height: 7),
                              _InfoRow(
                                icon: Icons.currency_rupee_rounded,
                                text: amount,
                                bold: true,
                              ),
                              if (appliedText != null) ...[
                                const SizedBox(height: 7),
                                _InfoRow(
                                  icon: Icons.event_rounded,
                                  text: "Applied on $appliedText",
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // status chip
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon(status), size: 13, color: color),
                              const SizedBox(width: 5),
                              Text(
                                status,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.visibility_rounded,
                            label: "View",
                            color: _navy,
                            filled: false,
                            onTap: () async {
                              final sponsor = await _sponsorFuture;
                              widget.onView({...data, "sponsorName": sponsor});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.delete_rounded,
                            label: "Delete",
                            color: _coral,
                            filled: true,
                            onTap: widget.onDelete,
                          ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;

  const _InfoRow({required this.icon, required this.text, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 12,
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ACTION BUTTON (hover + ripple)
// ============================================================

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final filled = widget.filled;
    final fg = filled ? Colors.white : color;
    final radius = BorderRadius.circular(10);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: filled
                ? (_hovering ? Color.lerp(color, Colors.black, 0.12) : color)
                : (_hovering ? color.withOpacity(0.08) : Colors.transparent),
            borderRadius: radius,
            border: filled ? null : Border.all(color: color),
            boxShadow: [
              if (_hovering)
                BoxShadow(
                  color: color.withOpacity(filled ? 0.35 : 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 17, color: fg),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAILS DIALOG
// ============================================================

class _DetailsDialog extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DetailsDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final studentName = _firstNonEmpty(
      [data["studentName"], data["name"]],
      "Unknown Student",
    );
    final scholarshipTitle = _firstNonEmpty(
      [data["scholarshipTitle"], data["scholarshipName"]],
      "Scholarship",
    );
    final status = _normalizeStatus(data["status"]);
    final color = _statusColor(status);
    final amount = _amountText(data["amount"]);
    final college = _firstNonEmpty(
      [data["college"], data["collegeName"]],
      "Not provided",
    );
    final email = _firstNonEmpty(
      [data["studentEmail"], data["email"]],
      "Not provided",
    );
    final mobile = _firstNonEmpty(
      [data["mobile"], data["phone"]],
      "Not provided",
    );
    final sponsorName = _firstNonEmpty([data["sponsorName"]], "Unknown Sponsor");
    final appliedAt = data["appliedAt"];

    final rows = <_DetailRow>[
      _DetailRow(
        icon: Icons.business_rounded,
        label: "Sponsor",
        value: sponsorName,
      ),
      _DetailRow(
        icon: Icons.account_balance_rounded,
        label: "College",
        value: college,
      ),
      _DetailRow(
        icon: Icons.email_rounded,
        label: "Email",
        value: email,
      ),
      _DetailRow(
        icon: Icons.phone_rounded,
        label: "Mobile",
        value: mobile,
      ),
      _DetailRow(
        icon: Icons.currency_rupee_rounded,
        label: "Amount",
        value: "₹$amount",
        highlight: true,
      ),
      if (appliedAt is Timestamp)
        _DetailRow(
          icon: Icons.event_rounded,
          label: "Applied on",
          value: _formatDate(appliedAt),
        ),
    ];

    return Dialog(
      backgroundColor: AppColors.card,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      Color.lerp(AppColors.primary, color, 0.25)!,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          studentName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
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
                            style: AppTextStyles.title.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scholarshipTitle,
                            style: AppTextStyles.subtitle.copyWith(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12.5,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(status), size: 13, color: color),
                          const SizedBox(width: 5),
                          Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // rows
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 350 + i * 80),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(20 * (1 - v), 0),
                            child: child,
                          ),
                        ),
                        child: rows[i],
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Close",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                label,
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                value,
                style: AppTextStyles.subtitle.copyWith(
                  color: _navy,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                  fontSize: highlight ? 15 : 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY STATE (floating icon)
// ============================================================

class _EmptyState extends StatefulWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final t = 2 * math.pi * _loop.value;
              final bob = 6 * math.sin(t);
              final pulse = 0.5 + 0.5 * math.sin(t);

              return SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96 + 30 * pulse,
                      height: 96 + 30 * pulse,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.06 * (1 - pulse)),
                      ),
                    ),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, bob),
                      child: Icon(
                        widget.icon,
                        size: 44,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Applications will appear here when available.",
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOADING SKELETON
// ============================================================

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final o = 0.10 + 0.14 * _c.value;

        Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(o),
            borderRadius: BorderRadius.circular(8),
          ),
        );

        return SizedBox(
          width: double.infinity,
          child: Column(
            children: List.generate(3, (i) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueGrey.withOpacity(o),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(160, 14),
                        const SizedBox(height: 12),
                        bar(230, 11),
                        const SizedBox(height: 8),
                        bar(130, 11),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}