import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                "Privacy Policy",
                style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Last updated: ${DateTime.now().year}",
                      style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 20),
                    const _Section(
                      title: "1. Information We Collect",
                      body:
                      "When you create an account, we collect your name, email, mobile number, date of "
                          "birth, state and district, college, course, year of study, roll number, category, "
                          "and annual family income. This information is provided directly by you during "
                          "sign-up and is used to determine your eligibility for scholarships.",
                    ),
                    const _Section(
                      title: "2. How We Use Your Information",
                      body:
                      "Your academic and financial details are used only to match you with scholarships "
                          "you are eligible for, and to share your application with the sponsor(s) you apply "
                          "to. Your contact details may be used to send you updates about your application "
                          "status.",
                    ),
                    const _Section(
                      title: "3. Who Can See Your Information",
                      body:
                      "Sponsors can view the details of students who apply to their scholarships. "
                          "Administrators can view platform-wide data for reporting and moderation purposes. "
                          "Your information is never sold to third parties.",
                    ),
                    const _Section(
                      title: "4. Document Storage",
                      body:
                      "Any documents you upload are stored securely using Firebase Storage and are only "
                          "accessible to you, the sponsor you applied to, and platform administrators.",
                    ),
                    const _Section(
                      title: "5. Data Storage & Security",
                      body:
                      "Your data is stored using Firebase Authentication and Cloud Firestore, which apply "
                          "industry-standard security practices. We take reasonable measures to protect your "
                          "information from unauthorized access.",
                    ),
                    const _Section(
                      title: "6. Your Rights",
                      body:
                      "You may update your profile information at any time from your account settings. "
                          "If you'd like your account and associated data removed, you can request this through "
                          "the platform's support contact.",
                    ),
                    const _Section(
                      title: "7. Changes to This Policy",
                      body:
                      "As the platform evolves, this policy may be updated to reflect new features or data "
                          "practices. Continued use of the app after changes means you accept the updated "
                          "policy.",
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.title.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary, fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }
}