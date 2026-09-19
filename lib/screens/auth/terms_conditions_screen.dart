import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
                "Terms & Conditions",
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
                      title: "1. About the Platform",
                      body:
                      "Scholarship Sponsor Connect is a platform that connects students seeking financial "
                          "support with sponsors offering scholarships. By creating an account, you agree to use "
                          "the platform honestly and only for its intended purpose of applying to, managing, or "
                          "funding scholarships.",
                    ),
                    const _Section(
                      title: "2. Eligibility & Accurate Information",
                      body:
                      "Students must provide accurate personal, academic, and financial details (such as "
                          "college, course, category, and annual family income) at the time of registration. "
                          "This information is used solely to determine eligibility for the scholarships you "
                          "apply to. Providing false information may result in your application being rejected "
                          "or your account being suspended.",
                    ),
                    const _Section(
                      title: "3. Sponsor Responsibilities",
                      body:
                      "Sponsors are responsible for the scholarships they publish, including eligibility "
                          "criteria, benefits, and selection process. Sponsors agree to review applications "
                          "fairly and communicate application decisions (Approved / Rejected) through the "
                          "platform's tracking system.",
                    ),
                    const _Section(
                      title: "4. Document Uploads",
                      body:
                      "Any documents you upload (such as ID proofs or income certificates) must be genuine "
                          "and belong to you. Do not upload suspicious, altered, or irrelevant files — uploads "
                          "are checked for file type, size, and naming before acceptance.",
                    ),
                    const _Section(
                      title: "5. Account Security",
                      body:
                      "You are responsible for keeping your login credentials confidential. Notify us "
                          "immediately if you suspect unauthorized access to your account.",
                    ),
                    const _Section(
                      title: "6. Platform Changes",
                      body:
                      "Since this platform is under active development, features, screens, and eligibility "
                          "logic may be updated over time to improve accuracy and user experience.",
                    ),
                    const _Section(
                      title: "7. Acceptance",
                      body:
                      "By checking \"I agree to the Terms & Conditions\" during sign-up, you confirm that "
                          "you have read and understood these terms and agree to be bound by them.",
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