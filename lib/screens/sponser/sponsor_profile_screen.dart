import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class SponsorProfileScreen extends StatelessWidget {
  const SponsorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header zone — matches student profile screen's gradient hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 36),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.secondary, width: 2.5),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.secondary.withOpacity(0.2),
                      child: Icon(Icons.business_rounded, size: 48, color: AppColors.secondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "ABC Foundation",
                    style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "abcfoundation@gmail.com",
                    style: AppTextStyles.subtitle.copyWith(color: Colors.white.withOpacity(0.75)),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoTile(icon: Icons.phone_rounded, label: "Phone", value: "+91 9876543210"),
                  const SizedBox(height: 14),
                  _InfoTile(icon: Icons.location_on_rounded, label: "Location", value: "Coimbatore, Tamil Nadu"),
                  const SizedBox(height: 14),
                  _InfoTile(icon: Icons.school_rounded, label: "Scholarships Published", value: "12 Scholarships"),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Edit Profile Coming Soon ✏️")),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 19),
                      label: const Text(
                        "Edit Profile",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Logout Coming Soon 🚪")),
                        );
                      },
                      icon: Icon(Icons.logout_rounded, size: 19, color: AppColors.error),
                      label: Text(
                        "Logout",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.error, width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
