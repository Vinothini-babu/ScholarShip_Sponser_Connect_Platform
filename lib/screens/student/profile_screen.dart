import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in"),
        ),
      );
    }
    final studentId = user.uid;

    final profileStream =
    FirebaseFirestore.instance
        .collection("users")
        .doc(studentId)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Profile",
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profileStream,

        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Something went wrong.\n\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Document doesn't exist
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_off_rounded,
                    size: 55,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Profile not found",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Please complete your profile first.",
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final Map<String, dynamic> data =
              snapshot.data!.data() ?? {};

          // ================================
          // PROFILE DATA
          // ================================

          final String name =
          (data["name"] ?? "Student").toString();

          final String email =
          (data["email"] ?? user.email ?? "Not added").toString();

          final String college =
          (data["college"] ?? "Not added").toString();

          final String course =
          (data["course"] ?? "Not added").toString();

          final String phone =
          (data["mobile"] ?? "Not added").toString();

          final String category =
          (data["category"] ?? "Not added").toString();

          final String percentage =
          (data["percentage"] ?? "Not added").toString();

          final String income =
          (data["annualIncome"] ?? "Not added").toString();

          return SingleChildScrollView(
            child: Column(
              children: [

                // ==========================================
                // PROFILE HEADER
                // ==========================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    30,
                    20,
                    35,
                  ),

                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.85),
                      ],
                    ),

                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),

                  child: Column(
                    children: [

                      Container(
                        padding: const EdgeInsets.all(3),

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.secondary,
                            width: 2.5,
                          ),
                        ),

                        child: CircleAvatar(
                          radius: 48,

                          backgroundColor:
                          AppColors.secondary.withOpacity(0.2),

                          child: Icon(
                            Icons.person_rounded,
                            size: 52,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        name,
                        style: AppTextStyles.title.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),

                        child: Text(
                          "Student",
                          style: AppTextStyles.subtitle.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // PROFILE INFORMATION
                // ==========================================

                Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [

                      _InfoTile(
                        icon: Icons.email_rounded,
                        label: "Email",
                        value: email,
                      ),

                      const SizedBox(height: 12),

                      _InfoTile(
                        icon: Icons.school_rounded,
                        label: "College",
                        value: college,
                      ),

                      const SizedBox(height: 12),

                      _InfoTile(
                        icon: Icons.menu_book_rounded,
                        label: "Course",
                        value: course,
                      ),

                      const SizedBox(height: 12),

                      _InfoTile(
                        icon: Icons.phone_rounded,
                        label: "Phone",
                        value: phone,
                      ),

                      const SizedBox(height: 12),

                      _InfoTile(
                        icon: Icons.category_rounded,
                        label: "Category",
                        value: category,
                      ),

                      const SizedBox(height: 12),

                      _InfoTile(
                        icon: Icons.percent_rounded,
                        label: "Percentage",
                        value: percentage,
                      ),

                      const SizedBox(height: 12),

                      _InfoTile(
                        icon: Icons.currency_rupee_rounded,
                        label: "Annual Income",
                        value: income,
                      ),

                      const SizedBox(height: 28),

                      // ====================================
                      // EDIT PROFILE BUTTON
                      // ====================================

                      SizedBox(
                        width: double.infinity,

                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showEditProfileDialog(
                              context: context,
                              uid: studentId,
                              name: name,
                              email: email,
                              college: college,
                              course: course,
                              phone: phone,
                              category: category,
                              percentage: percentage,
                              income: income,
                            );
                          },

                          icon: const Icon(
                            Icons.edit_rounded,
                            size: 19,
                          ),

                          label: const Text(
                            "Edit Profile",
                          ),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,

                            padding:
                            const EdgeInsets.symmetric(
                              vertical: 15,
                            ),

                            elevation: 0,

                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ====================================
                      // LOGOUT BUTTON
                      // ====================================

                      SizedBox(
                        width: double.infinity,

                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();

                            if (!context.mounted) return;

                            Navigator.pop(context);
                          },

                          icon: Icon(
                            Icons.logout_rounded,
                            size: 19,
                            color: AppColors.error,
                          ),

                          label: Text(
                            "Logout",
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.error,
                              width: 1.4,
                            ),

                            padding:
                            const EdgeInsets.symmetric(
                              vertical: 15,
                            ),

                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
// ==========================================================
  // EDIT PROFILE DIALOG
  // ==========================================================

  void _showEditProfileDialog({
    required BuildContext context,
    required String uid,
    required String name,
    required String email,
    required String college,
    required String course,
    required String phone,
    required String category,
    required String percentage,
    required String income,
  }) {
    final nameController =
    TextEditingController(text: name);

    final emailController =
    TextEditingController(text: email);

    final collegeController =
    TextEditingController(text: college);

    final courseController =
    TextEditingController(text: course);

    final phoneController =
    TextEditingController(text: phone);

    final categoryController =
    TextEditingController(text: category);

    final percentageController =
    TextEditingController(text: percentage);

    final incomeController =
    TextEditingController(text: income);

    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Edit Profile",
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),

          content: SizedBox(
            width: 500,

            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // NAME
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      prefixIcon:
                      Icon(Icons.person_rounded),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // EMAIL
                  TextField(
                    controller: emailController,
                    keyboardType:
                    TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon:
                      Icon(Icons.email_rounded),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // COLLEGE
                  TextField(
                    controller: collegeController,
                    decoration: const InputDecoration(
                      labelText: "College",
                      prefixIcon:
                      Icon(Icons.school_rounded),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // COURSE
                  TextField(
                    controller: courseController,
                    decoration: const InputDecoration(
                      labelText: "Course",
                      prefixIcon:
                      Icon(Icons.menu_book_rounded),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // PHONE
                  TextField(
                    controller: phoneController,
                    keyboardType:
                    TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Phone",
                      prefixIcon:
                      Icon(Icons.phone_rounded),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // CATEGORY
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: "Category",
                      prefixIcon:
                      Icon(Icons.category_rounded),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // PERCENTAGE
                  TextField(
                    controller:
                    percentageController,
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Percentage",
                      prefixIcon:
                      Icon(Icons.percent_rounded),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ANNUAL INCOME
                  TextField(
                    controller: incomeController,
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Annual Income",
                      prefixIcon:
                      Icon(
                        Icons.currency_rupee_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () async {
                await _updateProfile(
                  context: dialogContext,
                  uid: uid,
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  college: collegeController.text.trim(),
                  course: courseController.text.trim(),
                  phone: phoneController.text.trim(),
                  category:
                  categoryController.text.trim(),
                  percentage:
                  percentageController.text.trim(),
                  income:
                  incomeController.text.trim(),
                );
              },

              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // UPDATE PROFILE
  // ==========================================================

  Future<void> _updateProfile({
    required BuildContext context,
    required String uid,
    required String name,
    required String email,
    required String college,
    required String course,
    required String phone,
    required String category,
    required String percentage,
    required String income,
  }) async {
    try {
      final profileRef = FirebaseFirestore.instance
          .collection("users")
          .doc(uid);

      await profileRef.update({
        "name": name,
        "email": email,
        "college": college,
        "course": course,
        "mobile": phone,
        "category": category,
        "percentage": double.tryParse(percentage) ?? 0,
        "annualIncome": double.tryParse(income) ?? 0,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Profile updated successfully!",
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to update profile: $e",
          ),
        ),
      );
    }
  }
}

// ============================================================
// INFO TILE
// ============================================================

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius:
        BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset:
            const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: AppColors.secondary
                  .withOpacity(0.15),

              borderRadius:
              BorderRadius.circular(12),
            ),

            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(
                  label,
                  style:
                  AppTextStyles.subtitle
                      .copyWith(
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
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
          ),
        ],
      ),
    );
  }
}