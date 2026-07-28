import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

import 'manage_students_screen.dart';
import 'manage_sponsors_screen.dart';
import 'manage_scholarships_screen.dart';
import 'view_applications_screen.dart';
import 'reports_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Widget buildStatCard({
    required String title,
    required IconData icon,
    required Color color,
    required String collection,
  }) {
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

        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: color.withOpacity(.15),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.12),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withOpacity(.12),
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                count.toString(),
                style: AppTextStyles.title.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                title,
                style: AppTextStyles.subtitle.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                20,
                55,
                20,
                30,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(.85),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome Admin 👋",
                    style: AppTextStyles.subtitle.copyWith(
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Scholarship Sponsor Connect",
                    style: AppTextStyles.title.copyWith(
                      color: Colors.white,
                      fontSize: 25,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dashboard Overview",
                    style: AppTextStyles.title,
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: buildStatCard(
                          title: "Users",
                          icon: Icons.people,
                          color: Colors.blue,
                          collection: "students",
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: buildStatCard(
                          title: "Scholarships",
                          icon: Icons.school,
                          color: Colors.orange,
                          collection: "scholarships",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: buildStatCard(
                          title: "Applications",
                          icon: Icons.assignment,
                          color: Colors.green,
                          collection: "applications",
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: buildStatCard(
                          title: "Sponsors",
                          icon: Icons.business,
                          color: Colors.purple,
                          collection: "sponsors",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  Text(
                    "Management",
                    style: AppTextStyles.title,
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _NavCard(
                          icon: Icons.people,
                          title: "Students",
                          accent: AppColors.primary,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManageStudentsScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: _NavCard(
                          icon: Icons.business,
                          title: "Sponsors",
                          accent: AppColors.success,
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
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: _NavCard(
                          icon: Icons.school,
                          title: "Scholarships",
                          accent: AppColors.secondary,
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
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: _NavCard(
                          icon: Icons.assignment,
                          title: "Applications",
                          accent: AppColors.error,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const ViewApplicationsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  Text(
                    "Quick Actions",
                    style: AppTextStyles.title,
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.analytics,
                          title: "Reports",
                          accent: Colors.deepPurple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReportsScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: _ActionCard(
                          icon: Icons.settings,
                          title: "Settings",
                          accent: Colors.teal,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Settings Coming Soon ⚙️",
                                ),
                              ),
                            );
                          },
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
    );
  }
}

class _NavCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_NavCard> createState() => _NavCardState();
}

class _NavCardState extends State<_NavCard> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 115,
          transform: Matrix4.identity()
            ..scale(isHover ? 1.04 : 1.0),
          decoration: BoxDecoration(
            color: isHover
                ? widget.accent.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isHover
                  ? widget.accent
                  : widget.accent.withOpacity(.18),
              width: isHover ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withOpacity(
                  isHover ? .30 : .12,
                ),
                blurRadius: isHover ? 25 : 18,
                spreadRadius: isHover ? 3 : 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: widget.accent.withOpacity(.12),
                child: Icon(
                  widget.icon,
                  color: widget.accent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 115,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accent.withOpacity(.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(.12),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: accent.withOpacity(.12),
              child: Icon(
                icon,
                color: accent,
                size: 30,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              title,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}