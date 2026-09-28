import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'edit_scholarship_screen.dart';

// ============================================================
// HELPERS
// ============================================================

/// 1234567 -> "12,34,567" (Indian digit grouping)
String _formatIndian(num n) {
  final s = n.round().toString();
  if (s.length <= 3) return s;

  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return "${parts.join(',')},$last3";
}

num? _parseAmount(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  return num.tryParse(raw.toString().replaceAll(',', '').trim());
}

bool _isActive(dynamic status) => status.toString().toLowerCase() == "active";

// ============================================================
// SCREEN
// ============================================================

class ManageScholarshipsScreen extends StatefulWidget {
  const ManageScholarshipsScreen({super.key});

  @override
  State<ManageScholarshipsScreen> createState() =>
      _ManageScholarshipsScreenState();
}

class _ManageScholarshipsScreenState extends State<ManageScholarshipsScreen> {
  static const double _maxContentWidth = 1240;

  late final String? _uid;
  Stream<QuerySnapshot>? _stream;

  // "all" | "active" | "inactive"
  String _filter = "all";

  // Ids currently playing their delete-out animation.
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;

    // Created once — not inside build() — so a filter tap doesn't
    // re-subscribe and flash a loading spinner.
    if (_uid != null) {
      _stream = FirebaseFirestore.instance
          .collection("scholarships")
          .where("sponsorId", isEqualTo: _uid)
          .snapshots();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ----------------------------------------------------------
  // DELETE
  // ----------------------------------------------------------

  Future<void> _confirmAndDelete(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Delete Scholarship?",
                    style: AppTextStyles.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title.isEmpty
                        ? "This scholarship will be permanently removed."
                        : "\"$title\" will be permanently removed. This can't be undone.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Delete",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    // 1) play the shrink/fade-out, 2) then actually delete.
    setState(() => _removing.add(id));
    await Future.delayed(const Duration(milliseconds: 320));

    try {
      await FirebaseFirestore.instance
          .collection("scholarships")
          .doc(id)
          .delete();

      _snack("Scholarship deleted successfully");
    } catch (e) {
      _snack("Couldn't delete: $e");
    } finally {
      if (mounted) setState(() => _removing.remove(id));
    }
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return const Scaffold(body: Center(child: Text("Please login again")));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          final List<QueryDocumentSnapshot> all =
          List.of(snapshot.data?.docs ?? []);

          // Newest first (when createdAt exists).
          all.sort((a, b) {
            final ma = a.data() as Map<String, dynamic>;
            final mb = b.data() as Map<String, dynamic>;
            final ta = ma["createdAt"];
            final tb = mb["createdAt"];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });

          int activeCount = 0;
          num totalWorth = 0;
          for (final d in all) {
            final m = d.data() as Map<String, dynamic>;
            if (_isActive(m["status"])) activeCount++;
            totalWorth += _parseAmount(m["amount"]) ?? 0;
          }
          final int inactiveCount = all.length - activeCount;

          final List<QueryDocumentSnapshot> visible = all.where((d) {
            final m = d.data() as Map<String, dynamic>;
            final active = _isActive(m["status"]);
            if (_filter == "active") return active;
            if (_filter == "inactive") return !active;
            return true;
          }).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(maxWidth: _maxContentWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ---- Stats ----
                            _EntranceAnimation(
                              index: 0,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.school_rounded,
                                      label: "Total Scholarships",
                                      value: all.length.toDouble(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.check_circle_rounded,
                                      label: "Active",
                                      value: activeCount.toDouble(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.currency_rupee_rounded,
                                      label: "Total Worth",
                                      value: totalWorth.toDouble(),
                                      prefix: "₹",
                                      indian: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // ---- Filters ----
                            _EntranceAnimation(
                              index: 1,
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _FilterChipButton(
                                    label: "All",
                                    count: all.length,
                                    selected: _filter == "all",
                                    onTap: () =>
                                        setState(() => _filter = "all"),
                                  ),
                                  _FilterChipButton(
                                    label: "Active",
                                    count: activeCount,
                                    selected: _filter == "active",
                                    onTap: () =>
                                        setState(() => _filter = "active"),
                                  ),
                                  _FilterChipButton(
                                    label: "Inactive",
                                    count: inactiveCount,
                                    selected: _filter == "inactive",
                                    onTap: () =>
                                        setState(() => _filter = "inactive"),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            _buildBody(snapshot, all, visible),

                            const SizedBox(height: 30),
                          ],
                        ),
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

  Widget _buildBody(
      AsyncSnapshot<QuerySnapshot> snapshot,
      List<QueryDocumentSnapshot> all,
      List<QueryDocumentSnapshot> visible,
      ) {
    if (snapshot.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
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
      return SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (all.isEmpty) {
      return const _EmptyState(
        icon: Icons.school_outlined,
        title: "No Scholarships Published Yet",
        subtitle: "Scholarships you publish will show up here.",
      );
    }

    if (visible.isEmpty) {
      return _EmptyState(
        icon: Icons.filter_list_off_rounded,
        title: "No ${_filter == "active" ? "active" : "inactive"} scholarships",
        subtitle: "Try a different filter.",
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final int cols = w >= 1050 ? 3 : (w >= 680 ? 2 : 1);
        const double gap = 16;
        final double itemWidth = (w - gap * (cols - 1)) / cols;

        // Switching filters cross-fades the grid, and the cards
        // re-run their staggered entrance.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topLeft,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          child: Wrap(
            key: ValueKey(_filter),
            spacing: gap,
            runSpacing: gap,
            children: [
              for (int i = 0; i < visible.length; i++)
                SizedBox(
                  key: ValueKey(visible[i].id),
                  width: itemWidth,
                  child: _EntranceAnimation(
                    index: i + 2,
                    child: _buildCard(visible[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(QueryDocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;

    final String title = (m["title"] ?? "").toString();
    final String category = (m["category"] ?? "").toString();
    final String status = (m["status"] ?? "").toString();

    final num? amount = _parseAmount(m["amount"]);
    final String amountText = amount != null
        ? "₹${_formatIndian(amount)}"
        : ((m["amount"] ?? "").toString().isEmpty
        ? "—"
        : "₹${m["amount"]}");

    return _ScholarshipCard(
      title: title,
      amountText: amountText,
      category: category,
      status: status,
      removing: _removing.contains(doc.id),
      onEdit: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditScholarshipScreen(scholarshipId: doc.id),
          ),
        );
      },
      onDelete: () => _confirmAndDelete(doc.id, title),
    );
  }

  // ----------------------------------------------------------
  // HEADER
  // ----------------------------------------------------------

  Widget _buildHeader() {
    const radius = BorderRadius.only(
      bottomLeft: Radius.circular(36),
      bottomRight: Radius.circular(36),
    );

    Widget bubble(double size, double opacity) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: bubble(170, 0.07)),
            Positioned(bottom: -60, left: -40, child: bubble(190, 0.05)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 52),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Navigator.canPop(context)
                              ? IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.white,
                            onPressed: () => Navigator.pop(context),
                          )
                              : null,
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              "My Scholarships",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _EntranceAnimation(
                      index: 0,
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.secondary,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              size: 30,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Manage Your Scholarships",
                            style: AppTextStyles.title.copyWith(
                              color: Colors.white,
                              fontSize: 21,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Edit, track and remove the scholarships you've published",
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitle.copyWith(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
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
      ),
    );
  }
}

// ============================================================
// ENTRANCE ANIMATION (fade + slide up, staggered by index)
// ============================================================

class _EntranceAnimation extends StatefulWidget {
  final Widget child;
  final int index;

  const _EntranceAnimation({required this.child, this.index = 0});

  @override
  State<_EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<_EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  late final Animation<double> _fade =
  CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final int delay = math.min(widget.index, 10) * 70;
    Future.delayed(Duration(milliseconds: delay), () {
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

// ============================================================
// STAT CARD (count-up number)
// ============================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String prefix;
  final bool indian;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.prefix = "",
    this.indian = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              final String text =
              indian ? _formatIndian(v) : v.round().toString();
              return Text(
                "$prefix$text",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title.copyWith(fontSize: 20),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FILTER CHIP
// ============================================================

class _FilterChipButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondary.withOpacity(0.18),
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
                child: Text(label),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.22)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.primary,
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

// ============================================================
// SCHOLARSHIP CARD (hover lift + delete-out animation)
// ============================================================

class _ScholarshipCard extends StatefulWidget {
  final String title;
  final String amountText;
  final String category;
  final String status;
  final bool removing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScholarshipCard({
    required this.title,
    required this.amountText,
    required this.category,
    required this.status,
    required this.removing,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ScholarshipCard> createState() => _ScholarshipCardState();
}

class _ScholarshipCardState extends State<_ScholarshipCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _isActive(widget.status);
    final Color statusColor =
    active ? AppColors.success : AppColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: widget.removing ? 0 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
          scale: widget.removing ? 0.90 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hover
                    ? AppColors.primary.withOpacity(0.22)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hover ? 0.12 : 0.05),
                  blurRadius: _hover ? 24 : 12,
                  offset: Offset(0, _hover ? 12 : 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Accent bar (grows on hover)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: _hover ? 7 : 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.secondary,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon + status
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.workspace_premium_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.status.isEmpty
                                        ? "Unknown"
                                        : widget.status,
                                    style: AppTextStyles.subtitle.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Title (reserves 2 lines so cards in a row align)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Text(
                            widget.title.isEmpty ? "Untitled" : widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitle.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.35,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Amount + category
                        Row(
                          children: [
                            Text(
                              widget.amountText,
                              style: AppTextStyles.title.copyWith(
                                fontSize: 22,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (widget.category.isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.category_rounded,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          widget.category,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.subtitle.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.removing ? null : widget.onEdit,
                                icon: Icon(
                                  Icons.edit_rounded,
                                  size: 17,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  "Edit",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.primary,
                                    width: 1.4,
                                  ),
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                widget.removing ? null : widget.onDelete,
                                icon: const Icon(
                                  Icons.delete_rounded,
                                  size: 17,
                                ),
                                label: const Text(
                                  "Delete",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  AppColors.error.withOpacity(0.10),
                                  foregroundColor: AppColors.error,
                                  elevation: 0,
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE (gently floating icon)
// ============================================================

class _EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EntranceAnimation(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final double t =
                  Curves.easeInOut.transform(_controller.value);
                  return Transform.translate(
                    offset: Offset(0, -10 * t),
                    child: child,
                  );
                },
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 46,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}