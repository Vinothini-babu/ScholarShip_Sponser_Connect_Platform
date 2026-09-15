import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

import 'report_detail_screen.dart';

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
                  child: reportCard(
                    "Students",
                    Icons.people_alt_rounded,
                    Colors.blue,
                    "students",
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: reportCard(
                    "Sponsors",
                    Icons.business_rounded,
                    Colors.green,
                    "sponsors",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: reportCard(
                    "Scholarships",
                    Icons.school_rounded,
                    Colors.orange,
                    "scholarships",
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: reportCard(
                    "Applications",
                    Icons.assignment_rounded,
                    Colors.purple,
                    "applications",
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

            statusCard(),

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

            detailedTabs(context),

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

        final double trendPercent =
        count > 0 ? (newThisWeek / count) * 100 : 0;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                count.toString(),
                style: AppTextStyles.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: newThisWeek > 0
                      ? AppColors.success.withOpacity(.12)
                      : AppColors.textSecondary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      newThisWeek > 0
                          ? Icons.trending_up_rounded
                          : Icons.remove_rounded,
                      size: 12,
                      color: newThisWeek > 0
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      newThisWeek > 0
                          ? "+${trendPercent.toStringAsFixed(0)}% this week"
                          : "No change this week",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: newThisWeek > 0
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

        return Container(
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
              _statusRow(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                label: "Approved",
                value: approved,
                showDivider: true,
              ),
              _statusRow(
                icon: Icons.hourglass_top_rounded,
                color: Colors.orange,
                label: "Pending",
                value: pending,
                showDivider: true,
              ),
              _statusRow(
                icon: Icons.cancel_rounded,
                color: AppColors.error,
                label: "Rejected",
                value: rejected,
                showDivider: false,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color color,
    required String label,
    required int value,
    required bool showDivider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withOpacity(.08),
          ),
        )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            value.toString(),
            style: AppTextStyles.title.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAILED TABS
  // ============================================================

  Widget detailedTabs(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: "Students"),
                  Tab(text: "Sponsors"),
                  Tab(text: "Scholarships"),
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

            return _recordTile(
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

            return _recordTile(
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

            return _recordTile(
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textSecondary.withOpacity(.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
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
                    const SizedBox(height: 3),
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
                color: AppColors.textSecondary.withOpacity(.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}