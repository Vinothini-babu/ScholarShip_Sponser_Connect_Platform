import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

import 'report_detail_screen.dart';

/// Fades and slides a child up into place, with an optional
/// staggered start delay — used to animate cards/list rows in
/// one by one instead of popping in all at once.
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
      duration: const Duration(milliseconds: 420),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
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
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Lifts and scales a child slightly with a stronger shadow on mouse
/// hover (desktop) — falls back to a no-op tap ripple on touch.
class _HoverLift extends StatefulWidget {
  final Widget child;
  final double scale;

  const _HoverLift({
    required this.child,
    this.scale = 1.02,
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
            borderRadius: BorderRadius.circular(20),
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

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Reports",
          style: AppTextStyles.title.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              "Reports & Analytics",
              style: AppTextStyles.title.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              "Live overview of the scholarship platform",
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: _FadeSlideIn(
                    delayMs: 0,
                    child: reportCard(
                      "Students",
                      Icons.people_alt_rounded,
                      Colors.blue,
                      "students",
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _FadeSlideIn(
                    delayMs: 80,
                    child: reportCard(
                      "Sponsors",
                      Icons.business_rounded,
                      Colors.green,
                      "sponsors",
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _FadeSlideIn(
                    delayMs: 160,
                    child: reportCard(
                      "Scholarships",
                      Icons.school_rounded,
                      Colors.orange,
                      "scholarships",
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _FadeSlideIn(
                    delayMs: 240,
                    child: reportCard(
                      "Applications",
                      Icons.assignment_rounded,
                      Colors.purple,
                      "applications",
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              "Application Status",
              style: AppTextStyles.title.copyWith(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            _FadeSlideIn(delayMs: 320, child: statusCard()),

            const SizedBox(height: 28),

            Text(
              "All Records",
              style: AppTextStyles.title.copyWith(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              "Tap any entry to view full details",
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            _FadeSlideIn(delayMs: 400, child: detailedTabs(context)),

          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget reportCard(
      String title,
      IconData icon,
      Color color,
      String collection,
      ) {
    return StreamBuilder<QuerySnapshot>(
      stream: collection == "students"
          ? FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "student")
          .snapshots()
          : collection == "sponsors"
          ? FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "sponsor")
          .snapshots()
          : FirebaseFirestore.instance
          .collection(collection)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        int newThisWeek = 0;

        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          count = docs.length;

          final weekAgo = DateTime.now().subtract(
            const Duration(days: 7),
          );

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data["createdAt"] ??
                data["created_at"] ??
                data["timestamp"] ??
                data["dateCreated"];

            if (createdAt is Timestamp &&
                createdAt.toDate().isAfter(weekAgo)) {
              newThisWeek++;
            }
          }
        }

        return _HoverLift(
          scale: 1.03,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(.16),
                  color.withOpacity(.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(.28),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  count.toString(),
                  style: AppTextStyles.title.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: newThisWeek > 0
                      ? Container(
                    key: const ValueKey("new"),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.6),
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
                          newThisWeek == 1
                              ? "1 new"
                              : "$newThisWeek new",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  )
                      : const SizedBox(
                    key: ValueKey("none"),
                    height: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget statusCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("applications")
          .snapshots(),
      builder: (context, snapshot) {
        int approved = 0;
        int pending = 0;
        int rejected = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            if (data["status"] == "Approved") {
              approved++;
            } else if (data["status"] == "Rejected") {
              rejected++;
            } else {
              pending++;
            }
          }
        }

        return Column(
          children: [
            _statusRow(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              label: "Approved",
              value: approved,
            ),
            const SizedBox(height: 12),
            _statusRow(
              icon: Icons.hourglass_top_rounded,
              color: Colors.orange,
              label: "Pending",
              value: pending,
            ),
            const SizedBox(height: 12),
            _statusRow(
              icon: Icons.cancel_rounded,
              color: AppColors.error,
              label: "Rejected",
              value: rejected,
            ),
          ],
        );
      },
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color color,
    required String label,
    required int value,
  }) {
    return _HoverLift(
      scale: 1.015,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color.withOpacity(.14),
              color.withOpacity(.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.25), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
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
            Text(
              value.toString(),
              style: AppTextStyles.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAILED TABS
  // ============================================================

  Widget detailedTabs(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: "Students"),
                  Tab(text: "Sponsors"),
                  Tab(text: "Scholarships"),
                  Tab(text: "Applications"),
                ],
              ),
            ),

            SizedBox(
              height: 480,
              child: TabBarView(
                children: [
                  studentsList(context),
                  sponsorsList(context),
                  scholarshipsList(context),
                  applicationsList(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reads the first matching key from a document's data map, trying
  // a few common field-name variants.
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

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          message,
          style: AppTextStyles.subtitle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget studentsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "student")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyState("No students found");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final name = _field(data, ["name", "fullName", "studentName"]);
            final email = _field(data, ["email"]);
            final phone = _field(data, ["phone", "phoneNumber", "mobile"]);

            return _FadeSlideIn(
              delayMs: index * 40,
              child: _recordTile(
                context: context,
                icon: Icons.person_rounded,
                color: Colors.blue,
                title: name,
                subtitle: "$email  •  $phone",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(
                        headerTitle: name,
                        headerSubtitle: "Student",
                        icon: Icons.person_rounded,
                        color: Colors.blue,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget sponsorsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "sponsor")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyState("No sponsors found");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final name = _field(
              data,
              ["name", "organizationName", "companyName"],
            );
            final email = _field(data, ["email"]);
            final phone = _field(data, ["phone", "phoneNumber", "mobile"]);

            return _FadeSlideIn(
              delayMs: index * 40,
              child: _recordTile(
                context: context,
                icon: Icons.business_rounded,
                color: Colors.green,
                title: name,
                subtitle: "$email  •  $phone",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(
                        headerTitle: name,
                        headerSubtitle: "Sponsor",
                        icon: Icons.business_rounded,
                        color: Colors.green,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget scholarshipsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
      FirebaseFirestore.instance.collection("scholarships").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyState("No scholarships found");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final title = _field(data, ["title", "scholarshipName", "name"]);
            final amount = _field(data, ["amount", "scholarshipAmount"]);
            final sponsorName = _field(data, ["sponsorName", "sponsor"]);

            return _FadeSlideIn(
              delayMs: index * 40,
              child: _recordTile(
                context: context,
                icon: Icons.school_rounded,
                color: Colors.orange,
                title: title,
                subtitle: "Sponsor: $sponsorName",
                trailing: "₹$amount",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(
                        headerTitle: title,
                        headerSubtitle: "Scholarship",
                        icon: Icons.school_rounded,
                        color: Colors.orange,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget applicationsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
      FirebaseFirestore.instance.collection("applications").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyState("No applications found");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

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

            final rawStatus =
            _field(data, ["status"], fallback: "Pending");

            Color statusColor;
            IconData statusIcon;

            switch (rawStatus.toLowerCase()) {
              case "approved":
                statusColor = AppColors.success;
                statusIcon = Icons.check_circle_rounded;
                break;
              case "rejected":
                statusColor = AppColors.error;
                statusIcon = Icons.cancel_rounded;
                break;
              default:
                statusColor = Colors.orange;
                statusIcon = Icons.hourglass_top_rounded;
            }

            return _FadeSlideIn(
              delayMs: index * 40,
              child: _recordTile(
                context: context,
                icon: statusIcon,
                color: statusColor,
                title: studentName,
                subtitle: "Applied for: $scholarshipTitle",
                statusLabel: rawStatus,
                statusColor: statusColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(
                        headerTitle: studentName,
                        headerSubtitle: "Application — $rawStatus",
                        icon: statusIcon,
                        color: statusColor,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _recordTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailing,
    String? statusLabel,
    Color? statusColor,
  }) {
    return _HoverLift(
      scale: 1.015,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.035),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Accent strip
                Container(
                  width: 5,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),

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
                                color.withOpacity(.16),
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
                              statusLabel,
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
                            trailing,
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
    );
  }
}