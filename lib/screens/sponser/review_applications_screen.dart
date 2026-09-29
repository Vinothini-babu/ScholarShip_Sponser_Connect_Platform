import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/application_service.dart';
import 'applications/application_details_screen.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ReviewApplicationsScreen extends StatelessWidget {
  const ReviewApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Review Applications",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      // Privacy filter: students already awarded by ANOTHER sponsor are
      // hidden here (same filter the Applications Received screen uses).
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: ApplicationService().getVisibleSponsorApplicationDocs(
          FirebaseAuth.instance.currentUser?.uid ?? "",
        ),

        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Something went wrong\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          final applications = (snapshot.data ?? [])
              .where((d) => (d.data()["status"] ?? "").toString() == "Pending")
              .toList();

          if (applications.isEmpty) {
            return const Center(
              child: Text(
                "No Pending Applications",
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: applications.length,
            itemBuilder: (context, index) {

              final application =
              applications[index];

              final data = application.data();

              return _ApplicationCard(
                documentId: application.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }
}
class _ApplicationCard extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> data;

  const _ApplicationCard({
    required this.documentId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              CircleAvatar(
                radius: 24,
                backgroundColor:
                AppColors.primary.withOpacity(0.15),
                child: Icon(
                  Icons.person,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    Text(
                      data["studentName"] ?? "",
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      data["studentEmail"] ?? "",
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [

              const Icon(
                Icons.school,
                size: 18,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  data["scholarshipTitle"] ?? "",
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [

              const Icon(
                Icons.currency_rupee,
                size: 18,
              ),

              const SizedBox(width: 8),

              Text(
                data["amount"] ?? "",
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [

              const Icon(
                Icons.access_time,
                size: 18,
              ),

              const SizedBox(width: 8),

              Text(
                data["status"] ?? "",
                style: AppTextStyles.subtitle.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          Row(
            children: [

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Approve only from the full review screen, after the
                    // sponsor has viewed + verified the documents.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApplicationDetailsScreen(
                          data: data,
                          applicationId: documentId,
                        ),
                      ),
                    );
                  },

                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text("Review & Verify"),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {

                    final error = await ApplicationService().setStatusWithAward(
                      applicationId: documentId,
                      status: "Rejected",
                      sponsorId: FirebaseAuth.instance.currentUser!.uid,
                      studentId: (data["studentId"] ?? data["uid"])?.toString(),
                      scholarshipId: data["scholarshipId"]?.toString(),
                      extraAppFields: {},
                      wasApproved: false,
                    );

                    if (!context.mounted) return;

                    if (error != null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                      return;
                    }

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Application Rejected ❌",
                        ),
                      ),
                    );
                  },

                  icon: const Icon(Icons.close),
                  label: const Text("Reject"),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
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