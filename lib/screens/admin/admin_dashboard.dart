import 'package:flutter/material.dart';
import 'manage_scholarships_screen.dart';
import 'manage_sponsors_screen.dart';
import 'manage_students_screen.dart';
import 'view_applications_screen.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Combined gradient header — replaces AppBar + separate card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 26),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome Admin 👋",
                    style: AppTextStyles.subtitle.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Scholarship Sponsor Connect",
                    style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Overview", style: AppTextStyles.title.copyWith(fontSize: 18)),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _NavCard(
                          icon: Icons.people_rounded,
                          title: "Students",
                          accent: AppColors.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ManageStudentsScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _NavCard(
                          icon: Icons.business_rounded,
                          title: "Sponsors",
                          accent: AppColors.success,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ManageSponsorsScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _NavCard(
                          icon: Icons.school_rounded,
                          title: "Scholarships",
                          accent: AppColors.secondary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ManageScholarshipsScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _NavCard(
                          icon: Icons.assignment_rounded,
                          title: "Applications",
                          accent: AppColors.error,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ViewApplicationsScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  Text("Quick Actions", style: AppTextStyles.title.copyWith(fontSize: 18)),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.people_rounded,
                          title: "Manage Students",
                          accent: AppColors.primary,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Manage Students Coming Soon 🚀")),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.business_rounded,
                          title: "Manage Sponsors",
                          accent: AppColors.success,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Manage Sponsors Coming Soon 🚀")),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _NavCard(
                          icon: Icons.school_rounded,
                          title: "Manage Scholarship",
                          accent: AppColors.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ManageScholarshipsScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.analytics_rounded,
                          title: "Reports",
                          accent: AppColors.error,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Reports Coming Soon 🚀")),
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

/// Card that navigates to a page — fixed height so 2x2 rows never
/// produce mismatched/unwanted vertical gaps.
class _NavCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        splashColor: accent.withOpacity(0.12),
        highlightColor: accent.withOpacity(0.06),
        child: Container(
          height: 108,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card that shows a "Coming Soon" snackbar — visually identical to
/// _NavCard, kept as a separate widget to mirror the original file's
/// two distinct card behaviors (navigate vs. placeholder action).
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
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        splashColor: accent.withOpacity(0.12),
        highlightColor: accent.withOpacity(0.06),
        child: Container(
          height: 108,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

