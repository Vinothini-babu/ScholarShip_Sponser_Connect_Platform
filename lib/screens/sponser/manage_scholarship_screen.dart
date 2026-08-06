import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ManageScholarshipsScreen extends StatefulWidget {
  const ManageScholarshipsScreen({super.key});

  @override
  State<ManageScholarshipsScreen> createState() =>
      _ManageScholarshipsScreenState();
}

class _ManageScholarshipsScreenState
    extends State<ManageScholarshipsScreen> {

  @override
  Widget build(BuildContext context) {

    final sponsorId =
        FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "My Scholarships",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance
            .collection("scholarships")
            .where(
          "sponsorId",
          isEqualTo: sponsorId,
        )
            .orderBy(
          "createdAt",
          descending: true,
        )
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
              child: Text(
                "No Scholarships Published Yet",
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(

            padding: const EdgeInsets.all(20),

            itemCount: docs.length,

            itemBuilder: (context, index) {

              final doc = docs[index];

              final scholarship =
              doc.data() as Map<String, dynamic>;

              return Container(

                margin: const EdgeInsets.only(
                  bottom: 18,
                ),

                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius:
                  BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        0.05,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Text(
                      scholarship["title"] ?? "",
                      style: AppTextStyles.title,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Amount : ₹${scholarship["amount"]}",
                      style: AppTextStyles.subtitle,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Category : ${scholarship["category"]}",
                      style: AppTextStyles.subtitle,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Status : ${scholarship["status"]}",
                      style: AppTextStyles.subtitle,
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [

                        Expanded(
                          child: ElevatedButton.icon(

                            onPressed: () {

                              // Edit Scholarship
                              // Next Part-la connect pannuvom

                            },

                            icon: const Icon(Icons.edit),

                            label: const Text("Edit"),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
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

                              final confirm =
                              await showDialog<bool>(

                                context: context,

                                builder: (context) {

                                  return AlertDialog(

                                    title: const Text(
                                      "Delete Scholarship",
                                    ),

                                    content: const Text(
                                      "Are you sure you want to delete this scholarship?",
                                    ),

                                    actions: [

                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(
                                            context,
                                            false,
                                          );
                                        },
                                        child: const Text(
                                          "Cancel",
                                        ),
                                      ),

                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          Colors.red,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(
                                            context,
                                            true,
                                          );
                                        },
                                        child: const Text(
                                          "Delete",
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirm == true) {

                                await FirebaseFirestore.instance
                                    .collection(
                                  "scholarships",
                                )
                                    .doc(doc.id)
                                    .delete();

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(

                                  const SnackBar(
                                    content: Text(
                                      "Scholarship Deleted Successfully 🗑️",
                                    ),
                                  ),
                                );
                              }
                            },

                            icon: const Icon(Icons.delete),

                            label: const Text("Delete"),

                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              AppColors.error,
                              foregroundColor:
                              Colors.white,
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
            },
          );
        },
      ),
    );
  }
}