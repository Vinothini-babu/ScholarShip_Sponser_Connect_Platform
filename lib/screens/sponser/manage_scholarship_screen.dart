import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'edit_scholarship_screen.dart';

class ManageScholarshipsScreen extends StatefulWidget {
  const ManageScholarshipsScreen({super.key});

  @override
  State<ManageScholarshipsScreen> createState() => _ManageScholarshipsScreenState();
}

class _ManageScholarshipsScreenState extends State<ManageScholarshipsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "My Scholarships",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("scholarships")
            .where(
          "sponsorId",
          isEqualTo: FirebaseAuth.instance.currentUser!.uid,
        )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Error: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.error),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 60, color: AppColors.textSecondary),
                  const SizedBox(height: 14),
                  Text(
                    "No Scholarships Published Yet",
                    style: AppTextStyles.title.copyWith(fontSize: 17, color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final scholarship = doc.data() as Map<String, dynamic>;

              final title = scholarship["title"] ?? "";
              final amount = scholarship["amount"] ?? "";
              final category = scholarship["category"] ?? "";
              final status = scholarship["status"] ?? "";

              final isActive = status.toString().toLowerCase() == "active";
              final statusColor = isActive ? AppColors.success : AppColors.textSecondary;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: AppTextStyles.subtitle.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toString(),
                                  style: AppTextStyles.subtitle.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Icon(Icons.currency_rupee_rounded, size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                "$amount",
                                style: AppTextStyles.subtitle.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Icon(Icons.category_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "$category",
                                  style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditScholarshipScreen(
                                          scholarshipId: doc.id,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.edit_rounded, size: 17, color: AppColors.primary),
                                  label: Text("Edit", style: TextStyle(color: AppColors.primary)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppColors.primary, width: 1.4),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          title: Text(
                                            "Delete Scholarship",
                                            style: AppTextStyles.title.copyWith(fontSize: 17),
                                          ),
                                          content: Text(
                                            "Are you sure you want to delete this scholarship?",
                                            style: AppTextStyles.subtitle,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text(
                                                "Cancel",
                                                style: TextStyle(color: AppColors.textSecondary),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.error,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirm == true) {
                                      await FirebaseFirestore.instance
                                          .collection("scholarships")
                                          .doc(doc.id)
                                          .delete();

                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Scholarship Deleted Successfully 🗑️")),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.delete_rounded, size: 17),
                                  label: const Text("Delete"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
