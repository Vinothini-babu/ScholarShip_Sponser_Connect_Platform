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
  State<EditScholarshipScreen> createState() =>
      _EditScholarshipScreenState();
}

class _EditScholarshipScreenState
    extends State<EditScholarshipScreen> {

  final _formKey = GlobalKey<FormState>();

  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController amountController;
  late TextEditingController eligibilityController;
  late TextEditingController documentController;

  String? category;
  DateTime? lastDate;

  bool isLoading = false;

  final List<String> categories = [
    "Government",
    "Merit",
    "Sports",
    "Minority",
    "Private",
    "NGO",
    "International",
    "Education Loan",
  ];

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.scholarship["title"] ?? "",
    );

    descriptionController = TextEditingController(
      text: widget.scholarship["description"] ?? "",
    );

    amountController = TextEditingController(
      text: widget.scholarship["amount"] ?? "",
    );

    eligibilityController = TextEditingController(
      text: widget.scholarship["eligibility"] ?? "",
    );

    documentController = TextEditingController(
      text: widget.scholarship["requiredDocuments"] ?? "",
    );

    category = widget.scholarship["category"];

    if (widget.scholarship["lastDate"] != null) {
      lastDate =
          (widget.scholarship["lastDate"] as Timestamp)
              .toDate();
    }
  }

  Future<void> pickDate() async {

    final picked = await showDatePicker(
      context: context,
      initialDate: lastDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        lastDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text("Edit Scholarship"),
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Form(

          key: _formKey,

          child: Column(
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Scholarship Title",
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Scholarship Title";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Description";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Scholarship Amount",
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Amount";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: "Category",
                  prefixIcon: Icon(Icons.category),
                ),
                items: categories
                    .map(
                      (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    category = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return "Select Category";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: eligibilityController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Eligibility",
                  prefixIcon: Icon(Icons.verified_user),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Eligibility";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: documentController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Required Documents",
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Required Documents";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              InkWell(
                onTap: pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade400,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month),

                      const SizedBox(width: 12),

                      Text(
                        lastDate == null
                            ? "Select Last Date"
                            : "${lastDate!.day}/${lastDate!.month}/${lastDate!.year}",
                        style: AppTextStyles.subtitle,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {

                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    if (lastDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please select last date",
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    await FirebaseFirestore.instance
                        .collection("scholarships")
                        .doc(widget.documentId)
                        .update({

                      "title": titleController.text.trim(),

                      "description":
                      descriptionController.text.trim(),

                      "amount":
                      amountController.text.trim(),

                      "category": category,

                      "eligibility":
                      eligibilityController.text.trim(),

                      "requiredDocuments":
                      documentController.text.trim(),

                      "lastDate":
                      Timestamp.fromDate(lastDate!),
                    });

                    setState(() {
                      isLoading = false;
                    });

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Scholarship Updated Successfully 🎉",
                        ),
                      ),
                    );

                    Navigator.pop(context);
                  },
                  child: isLoading
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                      : const Text(
                    "Update Scholarship",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    eligibilityController.dispose();
    documentController.dispose();
    super.dispose();
  }
}