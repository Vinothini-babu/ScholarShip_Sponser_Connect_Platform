import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../utils/eligibility_utils.dart';
import 'eligible_scholarships_screen.dart';
import 'scholarship_info_screen.dart';

/// Shows EVERY active scholarship (from all sponsors) with a live
/// eligibility badge for the logged-in student. Opened from the
/// "Scholarships available" banner on the student dashboard.
class AllScholarshipsScreen extends StatefulWidget {
  const AllScholarshipsScreen({super.key});

  @override
  State<AllScholarshipsScreen> createState() => _AllScholarshipsScreenState();
}

class _AllScholarshipsScreenState extends State<AllScholarshipsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = "";
  bool _onlyEligible = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _money(dynamic v) {
    final s = (v ?? "").toString().trim();
    if (s.isEmpty) return "-";
    return s.startsWith("₹") ? s : "₹$s";
  }

  String _date(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    }
    return (v ?? "").toString();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid == null ? null : db.collection("users").doc(uid).snapshots(),
        builder: (context, userSnap) {
          final student = userSnap.data?.data() ?? <String, dynamic>{};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection("scholarships").where("status", isEqualTo: "Active").snapshots(),
            builder: (context, snap) {
              // newest first
              final all = List.of(snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
              all.sort((a, b) {
                final ta = a.data()["createdAt"];
                final tb = b.data()["createdAt"];
                if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
                return 0;
              });

              final q = _query.trim().toLowerCase();
              final items = all.where((d) {
                final data = d.data();
                final title = (data["title"] ?? "").toString().toLowerCase();
                final cat = (data["category"] ?? "").toString().toLowerCase();
                if (q.isNotEmpty && !title.contains(q) && !cat.contains(q)) return false;
                if (_onlyEligible && !isStudentEligibleForScholarship(data, student)) return false;
                return true;
              }).toList();

              final eligibleCount =
                  all.where((d) => isStudentEligibleForScholarship(d.data(), student)).length;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // ---------------- HEADER + STATS ----------------
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _Header(onBack: () => Navigator.pop(context)),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -52,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: SizedBox(
                                  height: 104,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.school_rounded,
                                          value: "${all.length}",
                                          label: "Total Scholarships",
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.check_circle_rounded,
                                          value: "$eligibleCount",
                                          label: "Eligible For You",
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.info_outline_rounded,
                                          value: "${all.length - eligibleCount}",
                                          label: "Not Eligible",
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 52 + 22),

                    // ---------------- BODY ----------------
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search bar
                              TextField(
                                controller: _search,
                                onChanged: (v) => setState(() => _query = v),
                                decoration: InputDecoration(
                                  hintText: "Search scholarships...",
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  filled: true,
                                  fillColor: AppColors.card,
                                  contentPadding:
                                  const EdgeInsets.symmetric(vertical: 0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Filter chips
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _FilterChip(
                                    label: "All",
                                    count: all.length,
                                    selected: !_onlyEligible,
                                    onTap: () =>
                                        setState(() => _onlyEligible = false),
                                  ),
                                  _FilterChip(
                                    label: "Eligible for me",
                                    count: eligibleCount,
                                    selected: _onlyEligible,
                                    onTap: () =>
                                        setState(() => _onlyEligible = true),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              _buildContent(snap, items, student),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
      Map<String, dynamic> student,
      ) {
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (snap.hasError) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            "Unable to load scholarships.\n\n${snap.error}",
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.error),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 70,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                "No Scholarships Found",
                style: AppTextStyles.title.copyWith(
                  fontSize: 19,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Try a different search or filter.",
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final doc in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ScholarshipCard(
              id: doc.id,
              data: doc.data(),
              eligible: isStudentEligibleForScholarship(doc.data(), student),
            ),
          ),
      ],
    );
  }
}

// =========================================================
// HEADER
// =========================================================

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 250,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.82),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: -40, top: 90, child: _circle(150)),
          Positioned(right: -30, top: -30, child: _circle(140)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "All Scholarships",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title.copyWith(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: AppColors.secondary, width: 2),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: AppColors.secondary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Browse Scholarships",
                  style: AppTextStyles.title.copyWith(
                    fontSize: 21,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Search all active scholarships and see which ones you qualify for",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// STAT CARD
// =========================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// FILTER CHIP
// =========================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.18),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.textSecondary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "$count",
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// SCHOLARSHIP CARD
// =========================================================

class _ScholarshipCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool eligible;

  const _ScholarshipCard({
    required this.id,
    required this.data,
    required this.eligible,
  });

  String _money(dynamic v) {
    final s = (v ?? "").toString().trim();
    if (s.isEmpty) return "-";
    return s.startsWith("₹") ? s : "₹$s";
  }

  String _date(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    }
    return (v ?? "").toString();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = eligible ? AppColors.success : AppColors.textSecondary;
    final category = (data["category"] ?? "").toString();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // gradient strip, matching the other redesigned screens
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
          ),

          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => eligible
                      ? const EligibleScholarshipsScreen()
                      : ScholarshipInfoScreen(scholarshipId: id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.school_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data["title"] ?? "").toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.currency_rupee_rounded,
                                  size: 14, color: AppColors.textSecondary),
                              Text(
                                _money(data["amount"]).replaceFirst("₹", ""),
                                style: AppTextStyles.subtitle.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ]),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(_date(data["lastDate"]),
                                  style: AppTextStyles.subtitle
                                      .copyWith(fontSize: 12)),
                            ]),
                            if (category.isNotEmpty)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.category_rounded,
                                    size: 13, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(category,
                                    style: AppTextStyles.subtitle
                                        .copyWith(fontSize: 12)),
                              ]),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        eligible
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 13,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        eligible ? "Eligible" : "Not eligible",
                        style: AppTextStyles.subtitle.copyWith(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}