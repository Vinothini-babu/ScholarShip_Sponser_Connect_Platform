import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

import 'manage_students_screen.dart';
import 'manage_sponsors_screen.dart';
import 'manage_scholarships_screen.dart';
import 'view_applications_screen.dart';
import 'reports_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Admin Control Center",
                      style: AppTextStyles.title.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Monitor and manage the scholarship platform",
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // STATISTICS
                    // ==========================================

                    _buildStatistics(),

                    const SizedBox(height: 30),

                    // ==========================================
                    // APPLICATION STATUS
                    // ==========================================

                    Text(
                      "Application Status",
                      style: AppTextStyles.title.copyWith(
                        fontSize: 20,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildApplicationStatus(),

                    const SizedBox(height: 30),

                    // ==========================================
                    // RECENT APPLICATIONS
                    // ==========================================

                    _buildSectionHeader(
                      title: "Recent Applications",
                      buttonText: "View All",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const ViewApplicationsScreen(
                              initialFilter: "All",
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    _buildRecentApplications(),

                    const SizedBox(height: 30),

                    // ==========================================
                    // RECENT SCHOLARSHIPS
                    // ==========================================

                    _buildSectionHeader(
                      title: "Recent Scholarships",
                      buttonText: "Manage",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const ManageScholarshipsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    _buildRecentScholarships(),

                    const SizedBox(height: 30),

                    // ==========================================
                    // QUICK ACTIONS
                    // ==========================================

                    Text(
                      "Quick Actions",
                      style: AppTextStyles.title.copyWith(
                        fontSize: 20,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildQuickActions(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        24,
        30,
        24,
        28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(.82),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome Admin 👋",
                  style: AppTextStyles.subtitle.copyWith(
                    color: Colors.white.withOpacity(.9),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "Scholarship Sponsor Connect",
                  style: AppTextStyles.title.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .snapshots(),
      builder: (context, usersSnapshot) {
        final usersCount =
            usersSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("scholarships")
              .snapshots(),
          builder: (context, scholarshipSnapshot) {
            final scholarshipCount =
                scholarshipSnapshot.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("applications")
                  .snapshots(),
              builder: (context, applicationSnapshot) {
                final applicationCount =
                    applicationSnapshot.data?.docs.length ?? 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .where(
                    "role",
                    isEqualTo: "sponsor",
                  )
                      .snapshots(),
                  builder: (context, sponsorSnapshot) {
                    final sponsorCount =
                        sponsorSnapshot.data?.docs.length ?? 0;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _AdminStatCard(
                            icon: Icons.people_alt_rounded,
                            title: "Total Users",
                            value: "$usersCount",
                            accent: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const ManageStudentsScreen(),
                                ),
                              );
                            },
                          ),

                          _AdminStatCard(
                            icon: Icons.school_rounded,
                            title: "Scholarships",
                            value: "$scholarshipCount",
                            accent: Colors.orange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const ManageScholarshipsScreen(),
                                ),
                              );
                            },
                          ),

                          _AdminStatCard(
                            icon: Icons.assignment_rounded,
                            title: "Applications",
                            value: "$applicationCount",
                            accent: Colors.green,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const ViewApplicationsScreen(
                                    initialFilter: "All",
                                  ),
                                ),
                              );
                            },
                          ),

                          _AdminStatCard(
                            icon: Icons.business_rounded,
                            title: "Sponsors",
                            value: "$sponsorCount",
                            accent: Colors.purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const ManageSponsorsScreen(),
                                ),
                              );
                            },
                          ),
                        ];

                        if (constraints.maxWidth > 800) {
                          return Row(
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 14),
                              Expanded(child: cards[1]),
                              const SizedBox(width: 14),
                              Expanded(child: cards[2]),
                              const SizedBox(width: 14),
                              Expanded(child: cards[3]),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 12),
                                Expanded(child: cards[1]),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(child: cards[2]),
                                const SizedBox(width: 12),
                                Expanded(child: cards[3]),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // APPLICATION STATUS
  // ============================================================

  Widget _buildApplicationStatus() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("applications")
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        int pending = 0;
        int approved = 0;
        int rejected = 0;

        for (final doc in docs) {
          final data =
          doc.data() as Map<String, dynamic>;

          final status =
              data["status"]?.toString().toLowerCase() ??
                  "pending";

          if (status == "approved") {
            approved++;
          } else if (status == "rejected") {
            rejected++;
          } else {
            pending++;
          }
        }

        final cards = [
          // ==========================================
          // PENDING
          // ==========================================

          _AdminStatusCard(
            icon: Icons.hourglass_top_rounded,
            title: "Pending",
            value: "$pending",
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const ViewApplicationsScreen(
                    initialFilter: "Pending",
                  ),
                ),
              );
            },
          ),

          // ==========================================
          // APPROVED
          // ==========================================

          _AdminStatusCard(
            icon: Icons.check_circle_rounded,
            title: "Approved",
            value: "$approved",
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const ViewApplicationsScreen(
                    initialFilter: "Approved",
                  ),
                ),
              );
            },
          ),

          // ==========================================
          // REJECTED
          // ==========================================

          _AdminStatusCard(
            icon: Icons.cancel_rounded,
            title: "Rejected",
            value: "$rejected",
            color: Colors.red,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const ViewApplicationsScreen(
                    initialFilter: "Rejected",
                  ),
                ),
              );
            },
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 700) {
              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[2]),
                ],
              );
            }

            return Column(
              children: [
                cards[0],
                const SizedBox(height: 10),
                cards[1],
                const SizedBox(height: 10),
                cards[2],
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // RECENT APPLICATIONS
  // ============================================================

  Widget _buildRecentApplications() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("applications")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const _AdminLoadingCard();
        }

        final docs = [
          ...?snapshot.data?.docs,
        ];

        docs.sort((a, b) {
          final aData =
          a.data() as Map<String, dynamic>;
          final bData =
          b.data() as Map<String, dynamic>;

          final aDate = aData["appliedAt"];
          final bDate = bData["appliedAt"];

          if (aDate is Timestamp &&
              bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }

          return 0;
        });

        final recentDocs =
        docs.take(5).toList();

        if (recentDocs.isEmpty) {
          return const _AdminEmptyCard(
            icon: Icons.assignment_outlined,
            message: "No applications yet",
          );
        }

        return Column(
          children: recentDocs.map((doc) {
            final data =
            doc.data() as Map<String, dynamic>;

            final studentName =
                data["studentName"]?.toString() ??
                    "Unknown Student";

            final scholarshipTitle =
                data["scholarshipTitle"]?.toString() ??
                    "Scholarship";

            final status =
                data["status"]?.toString() ??
                    "Pending";

            return _AdminRecentApplicationCard(
              studentName: studentName,
              scholarshipTitle: scholarshipTitle,
              status: status,
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // RECENT SCHOLARSHIPS
  // ============================================================

  Widget _buildRecentScholarships() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("scholarships")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const _AdminLoadingCard();
        }

        final docs = [
          ...?snapshot.data?.docs,
        ];

        docs.sort((a, b) {
          final aData =
          a.data() as Map<String, dynamic>;
          final bData =
          b.data() as Map<String, dynamic>;

          final aDate = aData["createdAt"];
          final bDate = bData["createdAt"];

          if (aDate is Timestamp &&
              bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }

          return 0;
        });

        final recentDocs =
        docs.take(4).toList();

        if (recentDocs.isEmpty) {
          return const _AdminEmptyCard(
            icon: Icons.school_outlined,
            message: "No scholarships available",
          );
        }

        return Column(
          children: recentDocs.map((doc) {
            final data =
            doc.data() as Map<String, dynamic>;

            final title =
                data["title"]?.toString() ??
                    data["scholarshipTitle"]?.toString() ??
                    "Scholarship";

            final amount =
                data["amount"]?.toString() ?? "0";

            final sponsorName =
                data["sponsorName"]?.toString() ??
                    "Sponsor";

            return _AdminRecentScholarshipCard(
              title: title,
              amount: amount,
              sponsorName: sponsorName,
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader({
    required String title,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.title.copyWith(
              fontSize: 20,
            ),
          ),
        ),

        TextButton(
          onPressed: onPressed,
          child: Text(
            buttonText,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = [
          _AdminQuickAction(
            icon: Icons.assignment_rounded,
            title: "Applications",
            subtitle: "Review applications",
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const ViewApplicationsScreen(
                    initialFilter: "All",
                  ),
                ),
              );
            },
          ),

          _AdminQuickAction(
            icon: Icons.people_alt_rounded,
            title: "Students",
            subtitle: "Manage students",
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const ManageStudentsScreen(),
                ),
              );
            },
          ),

          _AdminQuickAction(
            icon: Icons.business_rounded,
            title: "Sponsors",
            subtitle: "Manage sponsors",
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const ManageSponsorsScreen(),
                ),
              );
            },
          ),

          _AdminQuickAction(
            icon: Icons.analytics_rounded,
            title: "Reports",
            subtitle: "View reports",
            color: Colors.deepPurple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const ReportsScreen(),
                ),
              );
            },
          ),
        ];

        if (constraints.maxWidth > 750) {
          return Row(
            children: [
              Expanded(child: actions[0]),
              const SizedBox(width: 12),
              Expanded(child: actions[1]),
              const SizedBox(width: 12),
              Expanded(child: actions[2]),
              const SizedBox(width: 12),
              Expanded(child: actions[3]),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: actions[0]),
                const SizedBox(width: 12),
                Expanded(child: actions[1]),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: actions[2]),
                const SizedBox(width: 12),
                Expanded(child: actions[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// STAT CARD
// ============================================================

class _AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final VoidCallback? onTap;

  const _AdminStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withOpacity(.15),
            ),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 25,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                      AppTextStyles.subtitle.copyWith(
                        color:
                        AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      value,
                      style:
                      AppTextStyles.title.copyWith(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
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

// ============================================================
// STATUS CARD
// ============================================================

class _AdminStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _AdminStatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withOpacity(.07),
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: color.withOpacity(.16),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 27,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  title,
                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                value,
                style:
                AppTextStyles.title.copyWith(
                  fontSize: 22,
                  color: color,
                  fontWeight: FontWeight.bold,
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
// RECENT APPLICATION CARD
// ============================================================

class _AdminRecentApplicationCard
    extends StatelessWidget {
  final String studentName;
  final String scholarshipTitle;
  final String status;

  const _AdminRecentApplicationCard({
    required this.studentName,
    required this.scholarshipTitle,
    required this.status,
  });

  Color _statusColor() {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;

      case "rejected":
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Container(
      margin:
      const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
            AppColors.primary.withOpacity(.10),
            child: Text(
              studentName.isNotEmpty
                  ? studentName[0].toUpperCase()
                  : "?",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  scholarshipTitle,
                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    color:
                    AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RECENT SCHOLARSHIP CARD
// ============================================================

class _AdminRecentScholarshipCard
    extends StatelessWidget {
  final String title;
  final String amount;
  final String sponsorName;

  const _AdminRecentScholarshipCard({
    required this.title,
    required this.amount,
    required this.sponsorName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
      const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(.10),
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.orange,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  sponsorName,
                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    color:
                    AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Text(
            "₹$amount",
            style:
            AppTextStyles.title.copyWith(
              fontSize: 15,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// QUICK ACTION
// ============================================================

class _AdminQuickAction
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminQuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: color.withOpacity(.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius:
                  BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                      AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style:
                      AppTextStyles.subtitle.copyWith(
                        fontSize: 11,
                        color:
                        AppColors.textSecondary,
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

// ============================================================
// EMPTY CARD
// ============================================================

class _AdminEmptyCard
    extends StatelessWidget {
  final IconData icon;
  final String message;

  const _AdminEmptyCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: AppColors.textSecondary,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            style:
            AppTextStyles.subtitle.copyWith(
              color:
              AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOADING CARD
// ============================================================

class _AdminLoadingCard
    extends StatelessWidget {
  const _AdminLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
