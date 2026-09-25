import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'create_admin_screen.dart';

class ManageAdminsScreen extends StatelessWidget {
  const ManageAdminsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Manage Admins",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
            tooltip: "Add Admin",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateAdminScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .where("role", isEqualTo: "admin")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Unable to load admins.\n\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.error),
                ),
              ),
            );
          }

          final admins = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                "Admin Accounts",
                style: AppTextStyles.title.copyWith(fontSize: 22, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                "${admins.length} admin${admins.length == 1 ? '' : 's'} registered",
                style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 22),

              if (admins.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.admin_panel_settings_outlined, size: 55, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text("No Admins Found", style: AppTextStyles.title.copyWith(fontSize: 18)),
                      ],
                    ),
                  ),
                )
              else
                ...admins.map((admin) {
                  final data = admin.data() as Map<String, dynamic>;
                  final name = data["name"]?.toString().trim() ?? "";
                  final email = data["email"]?.toString().trim() ?? "";
                  final isSelf = admin.id == currentUid;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildAdminCard(
                      context,
                      documentId: admin.id,
                      name: name.isNotEmpty ? name : "Unnamed Admin",
                      email: email,
                      isSelf: isSelf,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdminCard(
      BuildContext context, {
        required String documentId,
        required String name,
        required String email,
        required bool isSelf,
      }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: AppTextStyles.title.copyWith(color: AppColors.primary, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text("You",
                            style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.email_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Expanded(child: Text(email, style: AppTextStyles.subtitle.copyWith(fontSize: 13))),
            ],
          ),
          const SizedBox(height: 18),

          // Self-removal is blocked — an admin should never be able to lock
          // themselves out, and if they're the only admin, removing them
          // would leave the platform with no one who can manage it.
          if (!isSelf)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _removeAdmin(context, documentId, name),
                icon: const Icon(Icons.delete_rounded, size: 17),
                label: const Text("Remove"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _removeAdmin(BuildContext context, String documentId, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Admin"),
        content: Text(
          "Are you sure you want to remove $name's admin access? "
              "This only removes their platform record — if they need to be "
              "fully blocked from signing in, also disable their account in "
              "Firebase Authentication.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection("users").doc(documentId).delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$name's admin access removed 🗑️")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove admin: $e")),
      );
    }
  }
}