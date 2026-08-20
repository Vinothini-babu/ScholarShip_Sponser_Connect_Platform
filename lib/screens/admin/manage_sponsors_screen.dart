import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ManageSponsorsScreen extends StatelessWidget {
  const ManageSponsorsScreen({super.key});

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
          "Manage Sponsors",
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
      // REAL FIREBASE SPONSORS
      // ============================================================

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .where(
          "role",
          isEqualTo: "sponsor",
        )
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
                  "Unable to load sponsors.\n\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            );
          }

          // --------------------------------------------------------
          // NO DATA
          // --------------------------------------------------------

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  "Registered Sponsors",
                  style: AppTextStyles.title.copyWith(
                    fontSize: 22,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "0 sponsors registered",
                  style: AppTextStyles.subtitle,
                ),

                const SizedBox(height: 40),

                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 55,
                        color: AppColors.textSecondary,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "No Sponsors Found",
                        style: AppTextStyles.title.copyWith(
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Registered sponsors will appear here.",
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // --------------------------------------------------------
          // REAL SPONSOR DOCUMENTS
          // --------------------------------------------------------

          final sponsors = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(20),

            children: [
              // ======================================================
              // TITLE
              // ======================================================

              Text(
                "Registered Sponsors",
                style: AppTextStyles.title.copyWith(
                  fontSize: 22,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              // REAL COUNT
              Text(
                "${sponsors.length} sponsors registered",
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 22),

              // ======================================================
              // SPONSOR LIST
              // ======================================================

              ...sponsors.map((sponsor) {
                final data =
                sponsor.data() as Map<String, dynamic>;

                final sponsorName =
                    data["name"]?.toString().trim() ?? "";

                final email =
                    data["email"]?.toString().trim() ?? "";

                final mobile =
                    data["mobile"]?.toString().trim() ?? "";

                final college =
                    data["college"]?.toString().trim() ?? "";

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16,
                  ),

                  child: _buildSponsorCard(
                    context,

                    documentId: sponsor.id,

                    sponsorName: sponsorName.isNotEmpty
                        ? sponsorName
                        : "Unknown Sponsor",

                    email: email,

                    mobile: mobile,

                    college: college,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // SPONSOR CARD
  // ============================================================

  Widget _buildSponsorCard(
      BuildContext context, {
        required String documentId,
        required String sponsorName,
        required String email,
        required String mobile,
        required String college,
      }) {
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
          // ========================================================
          // SPONSOR NAME
          // ========================================================

          Row(
            children: [
              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  color:
                  AppColors.secondary.withOpacity(.15),
                  shape: BoxShape.circle,
                ),

                child: Center(
                  child: Text(
                    sponsorName.isNotEmpty
                        ? sponsorName[0].toUpperCase()
                        : "?",

                    style:
                    AppTextStyles.title.copyWith(
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  sponsorName,

                  style:
                  AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ========================================================
          // EMAIL
          // ========================================================

          Row(
            children: [
              Icon(
                Icons.email_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  email.isNotEmpty
                      ? email
                      : "Email not available",

                  style:
                  AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                  ),

                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // ========================================================
          // MOBILE
          // ========================================================

          if (mobile.isNotEmpty) ...[
            const SizedBox(height: 7),

            Row(
              children: [
                Icon(
                  Icons.phone_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    mobile,

                    style:
                    AppTextStyles.subtitle.copyWith(
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ========================================================
          // ORGANIZATION
          // ========================================================

          if (college.isNotEmpty) ...[
            const SizedBox(height: 7),

            Row(
              children: [
                Icon(
                  Icons.business_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    college,

                    style:
                    AppTextStyles.subtitle.copyWith(
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),

          // ========================================================
          // BUTTONS
          // ========================================================

          Row(
            children: [
              // ----------------------------------------------------
              // VIEW
              // ----------------------------------------------------

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showSponsorDetails(
                      context,
                      sponsorName,
                      email,
                      mobile,
                      college,
                    );
                  },

                  icon: Icon(
                    Icons.visibility_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),

                  label: Text(
                    "View",
                    style: TextStyle(
                      color: AppColors.primary,
                    ),
                  ),

                  style:
                  OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),

                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 12,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ----------------------------------------------------
              // REMOVE
              // ----------------------------------------------------

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _removeSponsor(
                      context,
                      documentId,
                      sponsorName,
                    );
                  },

                  icon: const Icon(
                    Icons.delete_rounded,
                    size: 17,
                  ),

                  label: const Text(
                    "Remove",
                  ),

                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.error,

                    foregroundColor:
                    Colors.white,

                    elevation: 0,

                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 12,
                    ),

                    shape:
                    RoundedRectangleBorder(
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

  // ============================================================
  // VIEW SPONSOR DETAILS
  // ============================================================

  void _showSponsorDetails(
      BuildContext context,
      String name,
      String email,
      String mobile,
      String college,
      ) {
    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text(
            "Sponsor Details",
          ),

          content: Column(
            mainAxisSize:
            MainAxisSize.min,

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                "🏢 Name : $name",
              ),

              const SizedBox(height: 10),

              Text(
                "📧 Email : ${
                    email.isNotEmpty
                        ? email
                        : "Not available"
                }",
              ),

              if (mobile.isNotEmpty) ...[
                const SizedBox(height: 10),

                Text(
                  "📱 Mobile : $mobile",
                ),
              ],

              if (college.isNotEmpty) ...[
                const SizedBox(height: 10),

                Text(
                  "🏫 Organization : $college",
                ),
              ],
            ],
          ),

          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),

              child: const Text(
                "Close",
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // REMOVE SPONSOR
  // ============================================================

  Future<void> _removeSponsor(
      BuildContext context,
      String documentId,
      String sponsorName,
      ) async {
    final bool? confirm =
    await showDialog<bool>(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text(
            "Remove Sponsor",
          ),

          content: Text(
            "Are you sure you want to remove $sponsorName?",
          ),

          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    false,
                  ),

              child: const Text(
                "Cancel",
              ),
            ),

            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    true,
                  ),

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.error,

                foregroundColor:
                Colors.white,
              ),

              child: const Text(
                "Remove",
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      // ==========================================================
      // DELETE FROM FIRESTORE
      // ==========================================================

      await FirebaseFirestore.instance
          .collection("users")
          .doc(documentId)
          .delete();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "$sponsorName removed successfully 🗑️",
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
            "Failed to remove sponsor: $e",
          ),
        ),
      );
    }
  }
}