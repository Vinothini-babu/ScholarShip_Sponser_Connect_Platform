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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          "All Scholarships",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: uid == null ? null : db.collection("users").doc(uid).snapshots(),
            builder: (context, userSnap) {
              final student = userSnap.data?.data() ?? <String, dynamic>{};

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db.collection("scholarships").where("status", isEqualTo: "Active").snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text("Unable to load scholarships.\n\n${snap.error}",
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitle.copyWith(color: AppColors.error)),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }

                  // newest first
                  final all = List.of(snap.data!.docs);
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

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                        child: TextField(
                          controller: _search,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: "Search scholarships...",
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppColors.card,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text("All (${all.length})"),
                              selected: !_onlyEligible,
                              onSelected: (_) => setState(() => _onlyEligible = false),
                            ),
                            const SizedBox(width: 10),
                            ChoiceChip(
                              label: Text("Eligible for me ($eligibleCount)"),
                              selected: _onlyEligible,
                              onSelected: (_) => setState(() => _onlyEligible = true),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? Center(
                          child: Text("No scholarships found", style: AppTextStyles.subtitle),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final doc = items[i];
                            final data = doc.data();
                            final eligible = isStudentEligibleForScholarship(data, student);
                            return _card(context, doc.id, data, eligible);
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String id, Map<String, dynamic> d, bool eligible) {
    final badgeColor = eligible ? AppColors.success : AppColors.textSecondary;
    final category = (d["category"] ?? "").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
                  color: AppColors.primary.withOpacity(0.10),
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
                      (d["title"] ?? "").toString(),
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
                          Icon(Icons.currency_rupee_rounded, size: 14, color: AppColors.textSecondary),
                          Text(_money(d["amount"]).replaceFirst("₹", ""),
                              style: AppTextStyles.subtitle.copyWith(
                                  color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(_date(d["lastDate"]), style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
                        ]),
                        if (category.isNotEmpty)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.category_rounded, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(category, style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
                          ]),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(eligible ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 13, color: badgeColor),
                  const SizedBox(width: 4),
                  Text(
                    eligible ? "Eligible" : "Not eligible",
                    style: AppTextStyles.subtitle.copyWith(
                        color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}