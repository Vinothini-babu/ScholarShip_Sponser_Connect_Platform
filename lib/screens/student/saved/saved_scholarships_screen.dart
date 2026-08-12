import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/saved_scholarship_service.dart';

class SavedScholarshipsScreen extends StatelessWidget {
  SavedScholarshipsScreen({super.key});

  final SavedScholarshipService _service =
  SavedScholarshipService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Please login again"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
        title: Text(
          "Saved Scholarships",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      body: StreamBuilder(
        stream: _service.getSavedScholarships(user.uid),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Something went wrong",
                style: AppTextStyles.subtitle,
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),

                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 70,
                      color: AppColors.textSecondary,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      "No Saved Scholarships",
                      style: AppTextStyles.title.copyWith(
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Save scholarships you're interested in and find them here.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,

            itemBuilder: (context, index) {
              final data =
              docs[index].data()
              as Map<String, dynamic>;

              return Padding(
                padding:
                const EdgeInsets.only(bottom: 16),

                child: _SavedScholarshipCard(
                  service: _service,
                  studentId: user.uid,
                  scholarshipId:
                  data["scholarshipId"] ?? "",
                  title:
                  data["title"] ?? "Scholarship",
                  amount:
                  data["amount"] ?? "",
                  lastDate:
                  data["lastDate"] ?? "",
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedScholarshipCard
    extends StatelessWidget {

  final SavedScholarshipService service;
  final String studentId;
  final String scholarshipId;
  final String title;
  final String amount;
  final String lastDate;

  const _SavedScholarshipCard({
    required this.service,
    required this.studentId,
    required this.scholarshipId,
    required this.title,
    required this.amount,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(14),
                ),

                child: Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  AppTextStyles.title.copyWith(
                    fontSize: 16,
                    color:
                    AppColors.textPrimary,
                  ),
                ),
              ),

              IconButton(
                onPressed: () async {
                  await service
                      .removeSavedScholarship(
                    studentId: studentId,
                    scholarshipId:
                    scholarshipId,
                  );
                },

                icon: Icon(
                  Icons.favorite_rounded,
                  color: AppColors.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Icon(
                Icons.currency_rupee_rounded,
                size: 16,
                color: AppColors.primary,
              ),

              const SizedBox(width: 5),

              Text(
                amount,
                style:
                AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                  AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  "Deadline: $lastDate",
                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}