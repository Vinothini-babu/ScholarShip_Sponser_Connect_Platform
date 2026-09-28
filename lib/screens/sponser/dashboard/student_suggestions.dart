import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
// NOTE: adjust this path to where your eligibility_utils.dart lives
import '../../../utils/eligibility_utils.dart';

// =========================================================
// Data model for one suggested student (no phone / email —
// privacy: sponsor only sees academic + eligibility profile)
// =========================================================

class SuggestedStudent {
  final String uid;
  final Map<String, dynamic> data;
  final List<String> matchedScholarships;

  SuggestedStudent({
    required this.uid,
    required this.data,
    required this.matchedScholarships,
  });
}

// =========================================================
// SECTION: streams scholarships + applications + students and
// works out who matches this sponsor's scholarships.
//   - skips students already awarded (by ANY sponsor)
//   - skips students who already applied to this sponsor
// =========================================================

class StudentSuggestionSection extends StatelessWidget {
  final String sponsorId;
  const StudentSuggestionSection({super.key, required this.sponsorId});

  List<SuggestedStudent> _compute(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> scholarships,
      Set<String> appliedStudentIds,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> students,
      ) {
    final result = <SuggestedStudent>[];

    debugPrint("SUGGEST: ${scholarships.length} scholarships, ${students.length} users, ${appliedStudentIds.length} applied");

    for (final s in students) {
      final st = s.data();
      final name = (st["name"] ?? st["fullName"] ?? s.id).toString();

      // role check is case-insensitive ("student" / "Student")
      if ((st["role"] ?? "").toString().trim().toLowerCase() != "student") continue;

      if (st["isAwarded"] == true) {
        debugPrint("SUGGEST: skip $name -> already awarded");
        continue;
      }
      if (appliedStudentIds.contains(s.id)) {
        debugPrint("SUGGEST: skip $name -> already applied to this sponsor");
        continue;
      }

      final matched = <String>[];
      for (final sch in scholarships) {
        final sd = sch.data();
        final res = checkScholarshipEligibility(sd, st);
        final title = (sd["title"] ?? sd["scholarshipTitle"] ?? "Scholarship").toString();
        if (res.isEligible) {
          matched.add(title);
        } else {
          debugPrint("SUGGEST: $name x $title -> ${res.reasons.join(' | ')}");
        }
      }

      if (matched.isNotEmpty) {
        result.add(SuggestedStudent(uid: s.id, data: st, matchedScholarships: matched));
      }
    }

    // best academic first
    result.sort((a, b) => parseNumericValue(b.data["percentage"])
        .compareTo(parseNumericValue(a.data["percentage"])));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection("scholarships").where("sponsorId", isEqualTo: sponsorId).snapshots(),
      builder: (context, schSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection("applications").where("sponsorId", isEqualTo: sponsorId).snapshots(),
          builder: (context, appSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collection("users").snapshots(),
              builder: (context, stuSnap) {
                final scholarships = schSnap.data?.docs ?? [];
                final applied = (appSnap.data?.docs ?? [])
                    .map((d) => (d.data()["studentId"] ?? "").toString())
                    .toSet();
                final students = stuSnap.data?.docs ?? [];

                final suggestions = (scholarships.isEmpty || students.isEmpty)
                    ? <SuggestedStudent>[]
                    : _compute(scholarships, applied, students);

                final previewInitials = suggestions.take(3).map((x) {
                  final n = (x.data["name"] ?? x.data["fullName"] ?? "S").toString().trim();
                  return n.isEmpty ? "S" : n[0].toUpperCase();
                }).toList();

                return BlinkingSuggestionCard(
                  count: suggestions.length,
                  previewInitials: previewInitials,
                  hasScholarships: scholarships.isNotEmpty,
                  onTap: suggestions.isEmpty
                      ? null
                      : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SuggestedStudentsScreen(students: suggestions),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// =========================================================
// BLINKING SUGGESTION CARD
//   students found -> glowing orange gradient card, ripple icon,
//                     avatar stack, bouncing "View students" CTA,
//                     light-sweep shimmer
//   none           -> navy card with gold quote icon and rotating
//                     motivational quotes (fade + slide), progress dots
// =========================================================

class BlinkingSuggestionCard extends StatefulWidget {
  final int count;
  final List<String> previewInitials;
  final bool hasScholarships;
  final VoidCallback? onTap;

  const BlinkingSuggestionCard({
    super.key,
    required this.count,
    required this.hasScholarships,
    this.previewInitials = const [],
    this.onTap,
  });

  @override
  State<BlinkingSuggestionCard> createState() => _BlinkingSuggestionCardState();
}

class _BlinkingSuggestionCardState extends State<BlinkingSuggestionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _quoteTimer;
  int _quoteIndex = 0;

  static const _quotes = [
    "Every scholarship you create can change a life. 🌟",
    "Education is the most powerful weapon to change the world. 🎓",
    "Your generosity today builds someone's tomorrow. 💙",
    "New students join every day, stay tuned! 👀",
    "A small scholarship can be the start of a big dream. ✨",
  ];

  static const _orange1 = Color(0xFFFF9800);
  static const _orange2 = Color(0xFFFF5722);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();

    _quoteTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && widget.count == 0) {
        setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _quoteTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------
  // STUDENTS FOUND
  // ---------------------------------------------------------
  Widget _studentsCard(double v) {
    final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * v * 2); // 2 pulses / loop
    final n = widget.count;

    return Transform.scale(
      scale: 1 + 0.012 * pulse,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_orange1, _orange2],
            ),
            boxShadow: [
              BoxShadow(
                color: _orange2.withOpacity(0.30 + 0.35 * pulse),
                blurRadius: 14 + 18 * pulse,
                spreadRadius: 1 + 2 * pulse,
                offset: const Offset(0, 6),
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
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.28),
                          Colors.white.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // soft decorative circles
              Positioned(
                right: -25,
                top: -35,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.10)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    _rippleIcon(v, pulse),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "✨ TALENT MATCH",
                                  style: AppTextStyles.subtitle.copyWith(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "$n eligible student${n == 1 ? '' : 's'} match your scholarships!",
                            style: AppTextStyles.title.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "They haven't applied yet. Invite them and change a life 🎯",
                            style: AppTextStyles.subtitle.copyWith(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _avatarStack(),
                              _cta(pulse),
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
        ),
      ),
    );
  }

  Widget _rippleIcon(double v, double pulse) {
    Widget ring(double phaseShift) {
      final p = (v + phaseShift) % 1.0;
      return Container(
        width: 56 + 40 * p,
        height: 56 + 40 * p,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity((1 - p) * 0.6), width: 2),
        ),
      );
    }

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(0),
          ring(0.5),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Transform.scale(
              scale: 1 + 0.12 * pulse,
              child: const Icon(Icons.groups_rounded, color: _orange2, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarStack() {
    final initials = widget.previewInitials;
    final extra = widget.count - initials.length;
    final shown = initials.length + (extra > 0 ? 1 : 0);
    if (shown == 0) return const SizedBox.shrink();

    return SizedBox(
      width: 30.0 + (shown - 1) * 21,
      height: 32,
      child: Stack(
        children: [
          for (int i = 0; i < initials.length; i++)
            Positioned(
              left: i * 21.0,
              child: _avatar(initials[i], Colors.white, _orange2),
            ),
          if (extra > 0)
            Positioned(
              left: initials.length * 21.0,
              child: _avatar("+$extra", _orange2.withOpacity(0.85), Colors.white, small: true),
            ),
        ],
      ),
    );
  }

  Widget _avatar(String text, Color bg, Color fg, {bool small = false}) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: small ? 10.5 : 13),
      ),
    );
  }

  Widget _cta(double pulse) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "View students",
            style: TextStyle(color: _orange2, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          Transform.translate(
            offset: Offset(4 * pulse, 0),
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.arrow_forward_rounded, color: _orange2, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // QUOTES MODE
  // ---------------------------------------------------------
  Widget _quoteCard(double v) {
    final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * v);
    final gold = AppColors.secondary;
    final message = widget.hasScholarships
        ? _quotes[_quoteIndex]
        : "Add your first scholarship to start getting student suggestions 🚀";

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minHeight: 130),
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color.lerp(AppColors.primary, gold, 0.22)!],
        ),
        border: Border.all(color: gold.withOpacity(0.35 + 0.35 * pulse)),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.12 + 0.18 * pulse),
            blurRadius: 12 + 10 * pulse,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 4,
            top: -2,
            child: Opacity(
              opacity: 0.25 + 0.6 * pulse,
              child: Icon(Icons.auto_awesome_rounded, color: gold, size: 28),
            ),
          ),
          Positioned(
            right: 34,
            bottom: 2,
            child: Opacity(
              opacity: 0.85 - 0.6 * pulse,
              child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
            ),
          ),
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withOpacity(0.18),
                  border: Border.all(color: gold.withOpacity(0.7), width: 1.6),
                  boxShadow: [BoxShadow(color: gold.withOpacity(0.15 + 0.25 * pulse), blurRadius: 14 + 8 * pulse)],
                ),
                child: Transform.scale(
                  scale: 1 + 0.10 * pulse,
                  child: Icon(Icons.format_quote_rounded, color: gold, size: 38),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.center,
                        children: [...previous, if (current != null) current],
                      ),
                      child: Container(
                        key: ValueKey(message),
                        constraints: const BoxConstraints(minHeight: 56),
                        alignment: Alignment.center,
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    if (widget.hasScholarships) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < _quotes.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _quoteIndex ? 26 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _quoteIndex ? gold : Colors.white.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 86), // balances icon (68) + gap (18) -> text truly centred
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: KeyedSubtree(
            key: ValueKey(widget.count > 0),
            child: widget.count > 0 ? _studentsCard(_c.value) : _quoteCard(_c.value),
          ),
        );
      },
    );
  }
}

// =========================================================
// SUGGESTED STUDENTS SCREEN
// =========================================================

class SuggestedStudentsScreen extends StatelessWidget {
  final List<SuggestedStudent> students;
  const SuggestedStudentsScreen({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          "Suggested Students",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: students.length,
        itemBuilder: (context, i) => _SuggestedStudentCard(student: students[i]),
      ),
    );
  }
}

class _SuggestedStudentCard extends StatelessWidget {
  final SuggestedStudent student;
  const _SuggestedStudentCard({required this.student});

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(text, style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textPrimary)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = student.data;
    String v(String k) => (d[k] ?? "").toString();

    final name = v("name").isNotEmpty ? v("name") : (v("fullName").isNotEmpty ? v("fullName") : "Student");
    final pct = parseNumericValue(d["percentage"]);
    final income = parseNumericValue(d["annualIncome"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(Icons.person_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (v("course").isNotEmpty) _chip(Icons.menu_book_rounded, v("course")),
            if (v("year").isNotEmpty) _chip(Icons.timeline_rounded, "Year ${v("year")}"),
            _chip(Icons.percent_rounded, "${pct.toStringAsFixed(0)}%"),
            if (v("category").isNotEmpty) _chip(Icons.category_rounded, v("category")),
            _chip(Icons.currency_rupee_rounded, "Income ${income.toStringAsFixed(0)}"),
            if (v("college").isNotEmpty) _chip(Icons.account_balance_rounded, v("college")),
          ]),
          const SizedBox(height: 14),
          Text("Eligible for:",
              style: AppTextStyles.subtitle.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final t in student.matchedScholarships)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(t,
                      style: AppTextStyles.subtitle
                          .copyWith(fontSize: 13, color: AppColors.textPrimary)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}