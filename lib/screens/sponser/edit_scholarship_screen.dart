import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class EditScholarshipScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> scholarship;

  const EditScholarshipScreen({
    super.key,
    required this.documentId,
    required this.scholarship,
  });

  @override
  State<EditScholarshipScreen> createState() => _EditScholarshipScreenState();
}

class _EditScholarshipScreenState extends State<EditScholarshipScreen> {
  late TextEditingController titleController;
  late TextEditingController amountController;
  late TextEditingController eligibilityController;
  late TextEditingController deadlineController;
  late TextEditingController descriptionController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.scholarship["title"] ?? "");
    amountController = TextEditingController(text: widget.scholarship["amount"] ?? "");
    eligibilityController = TextEditingController(text: widget.scholarship["eligibility"] ?? "");
    deadlineController = TextEditingController(text: widget.scholarship["deadline"] ?? "");
    descriptionController = TextEditingController(text: widget.scholarship["description"] ?? "");
  }

  Future<void> _updateScholarship() async {
    if (titleController.text.trim().isEmpty ||
        amountController.text.trim().isEmpty ||
        eligibilityController.text.trim().isEmpty ||
        deadlineController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection("scholarships")
          .doc(widget.documentId)
          .update({
        "title": titleController.text.trim(),
        "amount": amountController.text.trim(),
        "eligibility": eligibilityController.text.trim(),
        "deadline": deadlineController.text.trim(),
        "description": descriptionController.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scholarship Updated Successfully 🎉")),
      );

      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    eligibilityController.dispose();
    deadlineController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.subtitle.copyWith(fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.secondary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Edit Scholarship",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: _fieldDecoration(label: "Scholarship Title", icon: Icons.school_rounded),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: _fieldDecoration(label: "Amount", icon: Icons.currency_rupee_rounded),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: eligibilityController,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: _fieldDecoration(label: "Eligibility", icon: Icons.verified_user_rounded),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: deadlineController,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: _fieldDecoration(label: "Deadline", icon: Icons.calendar_today_rounded),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: descriptionController,
              maxLines: 5,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: _fieldDecoration(label: "Description", icon: Icons.description_rounded)
                  .copyWith(alignLabelWithHint: true),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _updateScholarship,
                icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.save_rounded),
                label: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
                    : const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
