import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';

class SponsorProfileScreen extends StatefulWidget {
  const SponsorProfileScreen({super.key});

  @override
  State<SponsorProfileScreen> createState() => _SponsorProfileScreenState();
}

class _SponsorProfileScreenState extends State<SponsorProfileScreen> {
  final AuthService _authService = AuthService();

  final List<String> _stateOptions = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa",
    "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala",
    "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland",
    "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura",
    "Uttar Pradesh", "Uttarakhand", "West Bengal", "Andaman and Nicobar Islands",
    "Chandigarh", "Dadra and Nagar Haveli and Daman and Diu", "Delhi",
    "Jammu and Kashmir", "Ladakh", "Lakshadweep", "Puducherry",
  ];

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _authService.signOut();

    if (!mounted) return;
    // Clears the entire navigation stack so the sponsor can't swipe/back
    // their way back into the dashboard after logging out.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
    );
  }

  Future<void> _openEditProfile(String uid, Map<String, dynamic> currentData) async {
    final orgController = TextEditingController(text: currentData["organizationName"]?.toString() ?? "");
    final mobileController = TextEditingController(text: currentData["mobile"]?.toString() ?? "");
    final districtController = TextEditingController(text: currentData["district"]?.toString() ?? "");
    String? selectedState = currentData["state"]?.toString();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: orgController,
                  decoration: const InputDecoration(labelText: "Organization / Trust Name"),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Mobile Number"),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _stateOptions.contains(selectedState) ? selectedState : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: "State"),
                  items: _stateOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (value) => setDialogState(() => selectedState = value),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: districtController,
                  decoration: const InputDecoration(labelText: "District / City"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                if (orgController.text.trim().isEmpty || mobileController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Organization name and mobile can't be empty")),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  await FirebaseFirestore.instance.collection("users").doc(uid).update({
                    "organizationName": orgController.text.trim(),
                    "mobile": mobileController.text.trim(),
                    "state": selectedState,
                    "district": districtController.text.trim(),
                  });
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Couldn't update: $e")),
                    );
                  }
                }
              },
              child: isSaving
                  ? const SizedBox(
                height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login again")));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("users").doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Profile not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final String orgName = (data["organizationName"] ?? data["name"] ?? "Sponsor").toString();
          final String email = (data["email"] ?? "").toString();
          final String mobile = (data["mobile"] ?? "Not provided").toString();
          final String state = (data["state"] ?? "").toString();
          final String district = (data["district"] ?? "").toString();
          final String location = [district, state].where((s) => s.isNotEmpty).join(", ");

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header zone — matches student profile screen's gradient hero
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 36),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
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
                          border: Border.all(color: AppColors.secondary, width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.secondary.withOpacity(0.2),
                          child: Icon(Icons.business_rounded, size: 48, color: AppColors.secondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        orgName,
                        style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: AppTextStyles.subtitle.copyWith(color: Colors.white.withOpacity(0.75)),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _InfoTile(icon: Icons.phone_rounded, label: "Phone", value: mobile),
                      const SizedBox(height: 14),
                      _InfoTile(
                        icon: Icons.location_on_rounded,
                        label: "Location",
                        value: location.isEmpty ? "Not provided" : location,
                      ),
                      const SizedBox(height: 14),

                      // Live count — scholarships this sponsor has published.
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("scholarships")
                            .where("sponsorId", isEqualTo: user.uid)
                            .snapshots(),
                        builder: (context, schSnap) {
                          final count = schSnap.data?.docs.length ?? 0;
                          return _InfoTile(
                            icon: Icons.school_rounded,
                            label: "Scholarships Published",
                            value: "$count Scholarship${count == 1 ? '' : 's'}",
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openEditProfile(user.uid, data),
                          icon: const Icon(Icons.edit_rounded, size: 19),
                          label: const Text(
                            "Edit Profile",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _handleLogout,
                          icon: Icon(Icons.logout_rounded, size: 19, color: AppColors.error),
                          label: Text(
                            "Logout",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.error, width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
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