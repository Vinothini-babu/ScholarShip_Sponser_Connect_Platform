import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ManageScholarshipsScreen extends StatelessWidget {
  const ManageScholarshipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ============================================================
      // APP BAR
      // ============================================================

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,

        title: Text(
          "Manage Scholarships",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),

        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      // ============================================================
      // REAL FIRESTORE SCHOLARSHIPS
      // ============================================================

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("scholarships")
            .snapshots(),

        builder: (context, snapshot) {

          // --------------------------------------------------------
          // LOADING
          // --------------------------------------------------------

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // --------------------------------------------------------
          // ERROR
          // --------------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Error loading scholarships:\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            );
          }

          // --------------------------------------------------------
          // GET REAL FIRESTORE DATA
          // --------------------------------------------------------

          final scholarships =
              snapshot.data?.docs ?? [];

          // --------------------------------------------------------
          // EMPTY
          // --------------------------------------------------------

          if (scholarships.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Icon(
                    Icons.school_outlined,
                    size: 60,
                    color: AppColors.textSecondary,
                  ),

                  const SizedBox(height: 14),

                  Text(
                    "No Scholarships Found",
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "No scholarships are available yet.",
                    style: AppTextStyles.subtitle,
                  ),
                ],
              ),
            );
          }

          // ========================================================
          // SCHOLARSHIP LIST
          // ========================================================

          return ListView(
            padding: const EdgeInsets.all(20),

            children: [

              // ----------------------------------------------------
              // HEADER
              // ----------------------------------------------------

              Text(
                "Available Scholarships",
                style: AppTextStyles.title.copyWith(
                  fontSize: 22,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              // REAL COUNT
              Text(
                "${scholarships.length} scholarships available",
                style: AppTextStyles.subtitle,
              ),

              const SizedBox(height: 22),

              // ----------------------------------------------------
              // REAL FIRESTORE SCHOLARSHIPS
              // ----------------------------------------------------

              ...scholarships.map((scholarship) {

                final data =
                scholarship.data()
                as Map<String, dynamic>;

                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: 16),

                  child: _buildScholarshipCard(
                    context,

                    // Firestore document ID
                    documentId: scholarship.id,

                    // Support different field names
                    title:
                    data["title"]?.toString() ??
                        data["name"]?.toString() ??
                        "Untitled Scholarship",

                    sponsor:
                    data["sponsor"]?.toString() ??
                        data["sponsorName"]?.toString() ??
                        "Unknown Sponsor",

                    amount:
                    data["amount"]?.toString() ??
                        data["scholarshipAmount"]?.toString() ??
                        "Amount not specified",

                    accent: AppColors.primary,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // ==============================================================
  // SCHOLARSHIP CARD
  // ==============================================================

  Widget _buildScholarshipCard(
      BuildContext context, {
        required String documentId,
        required String title,
        required String sponsor,
        required String amount,
        required Color accent,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius:
        BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset:
            const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          // ========================================================
          // TOP ACCENT LINE
          // ========================================================

          Container(
            height: 5,

            decoration: BoxDecoration(
              color: accent,

              borderRadius:
              const BorderRadius.only(
                topLeft:
                Radius.circular(20),
                topRight:
                Radius.circular(20),
              ),
            ),
          ),

          // ========================================================
          // CONTENT
          // ========================================================

          Padding(
            padding:
            const EdgeInsets.all(18),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                // --------------------------------------------------
                // TITLE
                // --------------------------------------------------

                Text(
                  title,

                  style:
                  AppTextStyles.subtitle
                      .copyWith(
                    color:
                    AppColors.textPrimary,
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 12),

                // --------------------------------------------------
                // SPONSOR
                // --------------------------------------------------

                Row(
                  children: [

                    Icon(
                      Icons.business_rounded,
                      size: 15,
                      color:
                      AppColors.textSecondary,
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        sponsor,

                        style:
                        AppTextStyles.subtitle
                            .copyWith(
                          fontSize: 13,
                        ),

                        overflow:
                        TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                // --------------------------------------------------
                // AMOUNT
                // --------------------------------------------------

                Row(
                  children: [

                    Icon(
                      Icons
                          .currency_rupee_rounded,
                      size: 15,
                      color:
                      AppColors.textSecondary,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      amount,

                      style:
                      AppTextStyles.subtitle
                          .copyWith(
                        color:
                        AppColors.textPrimary,
                        fontWeight:
                        FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ==================================================
                // BUTTONS
                // ==================================================

                Row(
                  children: [

                    // ------------------------------------------------
                    // VIEW
                    // ------------------------------------------------

                    Expanded(
                      child:
                      OutlinedButton.icon(
                        onPressed: () {

                          _showScholarshipDetails(
                            context,
                            title,
                            sponsor,
                            amount,
                          );
                        },

                        icon: Icon(
                          Icons
                              .visibility_rounded,
                          size: 17,
                          color:
                          AppColors.primary,
                        ),

                        label: Text(
                          "View",
                          style:
                          TextStyle(
                            color:
                            AppColors.primary,
                          ),
                        ),

                        style:
                        OutlinedButton.styleFrom(
                          side: BorderSide(
                            color:
                            AppColors.primary,
                            width: 1.4,
                          ),

                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 12,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ------------------------------------------------
                    // DELETE
                    // ------------------------------------------------

                    Expanded(
                      child:
                      ElevatedButton.icon(
                        onPressed: () async {

                          await _deleteScholarship(
                            context,
                            documentId,
                            title,
                          );
                        },

                        icon: const Icon(
                          Icons
                              .delete_rounded,
                          size: 17,
                        ),

                        label:
                        const Text("Delete"),

                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          AppColors.error,

                          foregroundColor:
                          Colors.white,

                          elevation: 0,

                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 12,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(12),
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
  }

  // ==============================================================
  // VIEW SCHOLARSHIP DETAILS
  // ==============================================================

  void _showScholarshipDetails(
      BuildContext context,
      String title,
      String sponsor,
      String amount,
      ) {
    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(

          title: const Text(
            "Scholarship Details",
          ),

          content: Column(
            mainAxisSize:
            MainAxisSize.min,

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              Text(
                "🎓 Title : $title",
              ),

              const SizedBox(height: 10),

              Text(
                "🏢 Sponsor : $sponsor",
              ),

              const SizedBox(height: 10),

              Text(
                "💰 Amount : $amount",
              ),
            ],
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child:
              const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // ==============================================================
  // DELETE SCHOLARSHIP
  // ==============================================================

  Future<void> _deleteScholarship(
      BuildContext context,
      String documentId,
      String title,
      ) async {

    // ------------------------------------------------------------
    // CONFIRMATION
    // ------------------------------------------------------------

    final bool? confirm =
    await showDialog<bool>(
      context: context,

      builder: (_) {

        return AlertDialog(

          title: const Text(
            "Delete Scholarship",
          ),

          content: Text(
            "Are you sure you want to delete \"$title\"?",
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },

              child:
              const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.error,
                foregroundColor:
                Colors.white,
              ),

              child:
              const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    // ------------------------------------------------------------
    // DELETE FROM FIRESTORE
    // ------------------------------------------------------------

    try {

      await FirebaseFirestore.instance
          .collection("scholarships")
          .doc(documentId)
          .delete();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "$title deleted successfully 🗑️",
          ),
        ),
      );

    } catch (e) {

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete scholarship: $e",
          ),
        ),
      );
    }
  }
}