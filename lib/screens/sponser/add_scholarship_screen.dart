import 'package:flutter/material.dart';
import '../../services/scholarship_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class AddScholarshipScreen extends StatefulWidget {
  const AddScholarshipScreen({super.key});

  @override
  State<AddScholarshipScreen> createState() => _AddScholarshipScreenState();
}

class _AddScholarshipScreenState extends State<AddScholarshipScreen> {
  final ScholarshipService _scholarshipService = ScholarshipService();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController eligibilityController = TextEditingController();
  final TextEditingController deadlineController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool _isPublishing = false;

  Future<void> _handlePublish() async {
    if (titleController.text.isEmpty ||
        amountController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        deadlineController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      await _scholarshipService.addScholarship(
        title: titleController.text.trim(),
        amount: amountController.text.trim(),
        description: descriptionController.text.trim(),
        deadline: deadlineController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scholarship Published Successfully 🎉")),
      );

      titleController.clear();
      amountController.clear();
      eligibilityController.clear();
      deadlineController.clear();
      descriptionController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
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
          "Add Scholarship",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Publish New Scholarship",
              style: AppTextStyles.title.copyWith(fontSize: 22, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              "Fill the details below to publish a scholarship.",
              style: AppTextStyles.subtitle,
            ),

            const SizedBox(height: 28),

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
              decoration: _fieldDecoration(label: "Scholarship Amount", icon: Icons.currency_rupee_rounded),
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
              decoration: _fieldDecoration(label: "Application Deadline", icon: Icons.calendar_today_rounded),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: descriptionController,
              maxLines: 5,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: _fieldDecoration(label: "Scholarship Description", icon: Icons.description_rounded)
                  .copyWith(alignLabelWithHint: true),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isPublishing ? null : _handlePublish,
                icon: _isPublishing
                    ? const SizedBox.shrink()
                    : const Icon(Icons.publish_rounded),
                label: _isPublishing
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
                    : const Text(
                  "Publish Scholarship",
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

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
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
}
