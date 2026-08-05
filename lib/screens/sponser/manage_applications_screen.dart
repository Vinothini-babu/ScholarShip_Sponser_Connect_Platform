import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ManageApplicationsScreen extends StatelessWidget {
  const ManageApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Manage Applications",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("applications")
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No Applications Found"),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final doc = docs[index];

              final application =
              doc.data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      application["scholarshipTitle"] ?? "",
                      style: AppTextStyles.title,
                    ),

                    const SizedBox(height: 10),

                    Text("Student : ${application["studentName"]}"),

                    Text("Email : ${application["studentEmail"]}"),

                    Text("College : ${application["studentCollege"]}"),

                    Text("Status : ${application["status"]}"),

                    const SizedBox(height: 18),
                    Row(
                      children: [

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {

                              await FirebaseFirestore.instance
                                  .collection("applications")
                                  .doc(doc.id)
                                  .update({
                                "status": "Approved",
                              });

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Application Approved ✅",
                                  ),
                                ),
                              );
                            },

                            icon: const Icon(Icons.check),
                            label: const Text("Approve"),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {

                              await FirebaseFirestore.instance
                                  .collection("applications")
                                  .doc(doc.id)
                                  .update({
                                "status": "Rejected",
                              });

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}