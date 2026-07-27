import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditScholarshipScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> scholarship;

  const EditScholarshipScreen({
    super.key,
    required this.documentId,
    required this.scholarship,
  });

  @override
  State<EditScholarshipScreen> createState() =>
      _EditScholarshipScreenState();
}

class _EditScholarshipScreenState
    extends State<EditScholarshipScreen> {
  late TextEditingController titleController;
  late TextEditingController amountController;
  late TextEditingController eligibilityController;
  late TextEditingController deadlineController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.scholarship["title"] ?? "",
    );

    amountController = TextEditingController(
      text: widget.scholarship["amount"] ?? "",
    );

    eligibilityController = TextEditingController(
      text: widget.scholarship["eligibility"] ?? "",
    );

    deadlineController = TextEditingController(
      text: widget.scholarship["deadline"] ?? "",
    );

    descriptionController = TextEditingController(
      text: widget.scholarship["description"] ?? "",
    );
  }

  Future<void> _updateScholarship() async {
    if (titleController.text.trim().isEmpty ||
        amountController.text.trim().isEmpty ||
        eligibilityController.text.trim().isEmpty ||
        deadlineController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields"),
        ),
      );
      return;
    }

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
      const SnackBar(
        content: Text("Scholarship Updated Successfully 🎉"),
      ),
    );

    Navigator.pop(context);
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

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text("Edit Scholarship"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: fieldDecoration(
                "Scholarship Title",
                Icons.school,
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: fieldDecoration(
                "Amount",
                Icons.currency_rupee,
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: eligibilityController,
              decoration: fieldDecoration(
                "Eligibility",
                Icons.verified_user,
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: deadlineController,
              decoration: fieldDecoration(
                "Deadline",
                Icons.calendar_today,
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: descriptionController,
              maxLines: 5,
              decoration: fieldDecoration(
                "Description",
                Icons.description,
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _updateScholarship,
                icon: const Icon(Icons.save),
                label: const Text(
                  "Save Changes",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
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