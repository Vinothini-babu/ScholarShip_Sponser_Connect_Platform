import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

import 'search_screen.dart';
import 'scholarship_applications_screen.dart';
import 'profile_screen.dart';
import '../../models/scholarship_model.dart';
import '../../services/scholarship_service.dart';
import 'my_applications_screen.dart';
import '../../services/saved_scholarship_service.dart';
import 'saved/saved_scholarships_screen.dart';
import 'eligible_scholarships_screen.dart';
import 'scholarship_info_screen.dart';
import 'upload_documents_screen.dart';
import '../../utils/eligibility_utils.dart';
import 'all_scholarships_screen.dart';
import 'support_screen.dart';
import 'notification_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _navIndex = 0;

  final ScholarshipService scholarshipService = ScholarshipService();

  void _push(String name, Widget Function() builder) {
    debugPrint("NAV: tap -> $name");
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
    } catch (e) {
      debugPrint("NAV ERROR ($name): $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open $name: $e")),
      );
    }
  }

  void _handleNavTap(int index) {
    debugPrint("NAV: bottom tab $index");
    if (index == _navIndex) return;

    switch (index) {
      case 0:
        setState(() => _navIndex = 0);
        break;
      case 1:
        _push("Search", () => const SearchScreen());
        break;
      case 2:
        _push("My Applications", () => const MyApplicationsScreen());
        break;
      case 3:
        _push("Profile", () => const ProfileScreen());
        break;
    }
  }

  Future<void> _handleScholarshipTap(
      BuildContext context,
      String scholarshipId,
      ) async {
    debugPrint("NAV: scholarship card tapped -> $scholarshipId");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("NAV: currentUser is null");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final scholarshipDoc = await FirebaseFirestore.instance
          .collection('scholarships')
          .doc(scholarshipId)
          .get();

      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog

      if (!scholarshipDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This scholarship is no longer available")),
        );
        return;
      }

      final studentData = studentDoc.data() ?? {};
      final scholarshipData = scholarshipDoc.data() ?? {};

      final eligible = isStudentEligibleForScholarship(
        scholarshipData,
        studentData,
      );

      if (!context.mounted) return;

      if (eligible) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EligibleScholarshipsScreen(),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScholarshipInfoScreen(
              scholarshipId: scholarshipId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Something went wrong: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: InviteBannerHost(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection("users")
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        String name = (data?["name"] ??
                            data?["fullName"] ??
                            data?["userName"] ??
                            FirebaseAuth.instance.currentUser?.displayName ??
                            "")
                            .toString()
                            .trim();
                        if (name.isEmpty) name = "Student";
                        return _GradientHeader(userName: name, profile: data);
                      },
                    ),
                    Positioned(
                      bottom: -46,
                      left: 20,
                      right: 20,
                      child: _PromoBanner(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AllScholarshipsScreen()),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 66),

                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 22),
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 100),
                    child: InviteHighlightCard(),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const FadeSlideIn(
                    delay: Duration(milliseconds: 200),
                    child: _StatsGrid(),
                  ),
                ),

                const SizedBox(height: 30),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader(
                    title: "Trending Scholarships",
                    actionLabel: "See All",
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AllScholarshipsScreen()),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: SizedBox(
                    height: 240,
                    child: StreamBuilder<List<ScholarshipModel>>(
                      stream: scholarshipService.getScholarships(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }

                        if (snapshot.hasError) {
                          debugPrint("❌ Trending scholarships error: ${snapshot.error}");
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                "Unable to load scholarships.\n\n${snapshot.error}",
                                textAlign: TextAlign.center,
                                style: AppTextStyles.subtitle.copyWith(color: AppColors.error, fontSize: 12),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text("No Scholarships Available", style: AppTextStyles.subtitle),
                          );
                        }

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
                              onTap: () => _handleScholarshipTap(
                                context,
                                scholarship.id,
                              ),
                            );
                          },
                        );
                      },
                    ),
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
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 500),
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
                                MaterialPageRoute(builder: (_) => const MyApplicationsScreen()),
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
                                MaterialPageRoute(builder: (_) => SavedScholarshipsScreen()),
                              );
                            },
                          ),
                          _QuickAction(
                            icon: Icons.support_agent,
                            title: "Support",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SupportScreen()),
                              );
                            },
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
                            mainAxisExtent: 68,
                          ),
                          itemBuilder: (context, index) => actions[index],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
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

class _GradientHeader extends StatefulWidget {
  final String userName;
  final Map<String, dynamic>? profile;

  const _GradientHeader({required this.userName, this.profile});

  @override
  State<_GradientHeader> createState() => _GradientHeaderState();
}

class _GradientHeaderState extends State<_GradientHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  }

  /// first non-empty value among several possible Firestore keys
  String _pick(List<String> keys) {
    final p = widget.profile;
    if (p == null) return "";
    for (final k in keys) {
      final v = (p[k] ?? "").toString().trim();
      if (v.isNotEmpty) return v;
    }
    return "";
  }

  String _yearText() {
    final y = _pick(["year", "currentYear", "studyYear", "yearOfStudy"]);
    if (y.isEmpty) return "";
    return RegExp(r'^\d+$').hasMatch(y) ? "Year $y" : y;
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subtitle.copyWith(
                color: Colors.white.withOpacity(0.95),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _twinkle(double t, double phase,
      {double? right, double? top, double? left, double? bottom, double size = 4}) {
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
          boxShadow: [BoxShadow(color: Colors.white.withOpacity(o * 0.8), blurRadius: 6)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.secondary;
    final name = widget.userName;

    final course = _pick(["course", "department", "degree", "branch"]);
    final year = _yearText();
    final college = _pick(["college", "collegeName", "institution", "institute"]);
    final district = _pick(["district", "city"]);
    final state = _pick(["state"]);
    final location = [district, state].where((e) => e.isNotEmpty).join(", ");
    final courseLine = [course, year].where((e) => e.isNotEmpty).join(" • ");

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
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 66),
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
                top: -40 + 10 * drift2,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.03),
                    ]),
                  ),
                ),
              ),
              Positioned(
                right: 120 + 16 * drift2,
                bottom: -60 + 8 * drift,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withOpacity(0.10)),
                ),
              ),
              _twinkle(t, 0, right: 90, top: 34),
              _twinkle(t, 1.6, right: 210, top: 78, size: 3),
              _twinkle(t, 3.1, right: 40, bottom: 20, size: 5),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "${_greeting()} ",
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Transform.rotate(
                        angle: 0.45 * math.sin(t * 4),
                        alignment: Alignment.bottomRight,
                        child: const Text("👋", style: TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, e, child) => Opacity(
                      opacity: e,
                      child: Transform.translate(offset: Offset(-24 * (1 - e), 0), child: child),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: gold.withOpacity(0.55 + 0.45 * pulse), width: 2.2),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withOpacity(0.20 + 0.30 * pulse),
                                blurRadius: 10 + 12 * pulse,
                                spreadRadius: 1 + 2 * pulse,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "S",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (rect) => LinearGradient(
                                  begin: Alignment(-2 + 4 * v, 0),
                                  end: Alignment(-1 + 4 * v, 0),
                                  colors: const [Colors.white, Color(0xFFFFE7A0), Colors.white],
                                ).createShader(rect),
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.title.copyWith(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (courseLine.isNotEmpty)
                                    _chip(Icons.menu_book_rounded, courseLine),
                                  if (college.isNotEmpty)
                                    _chip(Icons.account_balance_rounded, college),
                                  if (location.isNotEmpty)
                                    _chip(Icons.location_on_rounded, location),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Positioned(top: -6, right: 0, child: NotificationBell()),
            ],
          ),
        );
      },
    );
  }
}

/// ------------------------------------------------------------
/// PROMO CARD  (live count of active scholarships, tap -> all)
/// ------------------------------------------------------------

class _PromoBanner extends StatefulWidget {
  final VoidCallback onTap;
  const _PromoBanner({required this.onTap});

  @override
  State<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<_PromoBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.secondary;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("scholarships")
          .where("status", isEqualTo: "Active")
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final total = docs.length;
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final newThisWeek = docs.where((d) {
          final t = d.data()["createdAt"];
          return t is Timestamp && t.toDate().isAfter(weekAgo);
        }).length;

        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * v);

            return InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: gold.withOpacity(0.35 + 0.35 * pulse)),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withOpacity(0.18 + 0.22 * pulse),
                      blurRadius: 16 + 12 * pulse,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // light sweep
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-2.5 + 5 * v, -0.4),
                              end: Alignment(-1.5 + 5 * v, 0.4),
                              colors: [
                                gold.withOpacity(0),
                                gold.withOpacity(0.16),
                                gold.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [gold, Color.lerp(gold, Colors.deepOrange, 0.35)!],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: gold.withOpacity(0.25 + 0.30 * pulse),
                                  blurRadius: 10 + 8 * pulse,
                                ),
                              ],
                            ),
                            child: Transform.scale(
                              scale: 1 + 0.10 * pulse,
                              child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 26),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snap.hasData
                                      ? "$total Scholarships Available"
                                      : "Loading scholarships...",
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  newThisWeek > 0
                                      ? "$newThisWeek added this week ✨ Tap to browse all"
                                      : "Tap to browse all & check your eligibility",
                                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(4 * pulse, 0),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: gold.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_forward_rounded, size: 18, color: gold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

    // Active scholarships
    final scholarshipStream = firestore
        .collection("scholarships")
        .where("status", isEqualTo: "Active")
        .snapshots();

    // Student profile
    final userStream = firestore
        .collection("users")
        .doc(studentId)
        .snapshots();

    // Student applications
    final applicationStream = firestore
        .collection("applications")
        .where(
      "studentId",
      isEqualTo: studentId,
    )
        .snapshots();

    final savedService = SavedScholarshipService();

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),

          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 132,
          ),

          children: [

            // =================================================
            // 1. SCHOLARSHIPS
            // =================================================

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: scholarshipStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("❌ Scholarships stat error: ${snapshot.error}");
                }
                final count =
                    snapshot.data?.docs.length ?? 0;

                return _buildStatCard(
                  icon: Icons.school_rounded,
                  title: "Scholarships",
                  value: "$count",
                  color: AppColors.primary,

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ),
                    );
                  },
                );
              },
            ),

            // =================================================
            // 2. APPLIED
            // =================================================

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: applicationStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("❌ Applications stat error: ${snapshot.error}");
                }
                final count =
                    snapshot.data?.docs.length ?? 0;

                return _buildStatCard(
                  icon: Icons.assignment_turned_in_rounded,
                  title: "Applied",
                  value: "$count",
                  color: AppColors.success,

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const MyApplicationsScreen(),
                      ),
                    );
                  },
                );
              },
            ),

            // =================================================
            // 3. SAVED
            // ==================================================
            StreamBuilder<int>(
              stream: savedService.getSavedCount(studentId),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;

                return _buildStatCard(
                  icon: Icons.favorite_rounded,
                  title: "Saved",
                  value: "$count",
                  color: AppColors.error,

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SavedScholarshipsScreen(),
                      ),
                    );
                  },
                );
              },
            ),

            // =================================================
            // 4. ELIGIBLE
            // =================================================

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: scholarshipStream,
              builder: (
                  context,
                  scholarshipSnapshot,
                  ) {
                if (!scholarshipSnapshot.hasData) {
                  return _buildStatCard(
                    icon:
                    Icons.workspace_premium_rounded,
                    title: "Eligible",
                    value: "0",
                    color: AppColors.secondary,

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const EligibleScholarshipsScreen(),
                        ),
                      );
                    },
                  );
                }

                final scholarshipDocs =
                    scholarshipSnapshot.data!.docs;

                return StreamBuilder<
                    DocumentSnapshot<Map<String, dynamic>>>(
                  stream: userStream,
                  builder: (
                      context,
                      userSnapshot,
                      ) {
                    int eligibleCount = 0;

                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final userData = userSnapshot.data!.data() ?? {};

                      // Same shared logic used by the scholarship tap and
                      // the Eligible screen, so counts always match and
                      // List/String eligibleCourse values both work.
                      for (final doc in scholarshipDocs) {
                        if (isStudentEligibleForScholarship(
                          doc.data(),
                          userData,
                        )) {
                          eligibleCount++;
                        }
                      }
                    }

                    return _buildStatCard(
                      icon:
                      Icons.workspace_premium_rounded,
                      title: "Eligible",
                      value: "$eligibleCount",
                      color: AppColors.secondary,

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const EligibleScholarshipsScreen(),
                          ),
                        );
                      },
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

  // =======================================================
  // CONVERT FIREBASE VALUE TO DOUBLE
  // =======================================================

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().trim(),
    ) ??
        0;
  }

  // =======================================================
  // STAT CARD
  // =======================================================

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return _TapFeedback(
      borderRadius: BorderRadius.circular(16),

      onTap: onTap ?? () {},

      child: Container(
        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
          BorderRadius.circular(18),

          border: Border.all(
            color:
            color.withValues(alpha: .22),
            width: 1.3,
          ),

          boxShadow: [
            BoxShadow(
              color:
              color.withValues(alpha: .14),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            Container(
              width: 42,
              height: 42,

              decoration: BoxDecoration(
                color:
                color.withValues(alpha: .15),
                shape: BoxShape.circle,
              ),

              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              value,

              style:
              AppTextStyles.title.copyWith(
                fontSize: 22,
                color:
                AppColors.textPrimary,
              ),
            ),

            Text(
              title,

              style:
              AppTextStyles.subtitle.copyWith(
                fontWeight:
                FontWeight.w600,
                fontSize: 13,
              ),

              overflow:
              TextOverflow.ellipsis,
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
          width: 188,
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
                    height: 66,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: .75)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                  ),

                  // ❤️ Save Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: StreamBuilder<bool>(
                      stream: SavedScholarshipService().isSaved(
                        studentId: FirebaseAuth.instance.currentUser!.uid,
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
                              final service = SavedScholarshipService();
                              final studentId = FirebaseAuth.instance.currentUser!.uid;

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
                              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isSaved ? AppColors.error : AppColors.textSecondary,
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
                        Icon(Icons.calendar_today, size: 13, color: AppColors.textSecondary),
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

      // IMPORTANT:
      // Use the onTap received from the dashboard
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textSecondary.withValues(
              alpha: .12,
            ),
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
              child: Icon(
                icon,
                color: AppColors.secondary,
                size: 19,
              ),
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