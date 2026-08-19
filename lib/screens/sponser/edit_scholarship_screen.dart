import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class EditScholarshipScreen extends StatefulWidget {
  final String scholarshipId;

  const EditScholarshipScreen({
    super.key,
    required this.scholarshipId,
  });

  @override
  State<EditScholarshipScreen> createState() =>
      _EditScholarshipScreenState();
}

class _EditScholarshipScreenState
    extends State<EditScholarshipScreen> {

  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  final eligibilityController = TextEditingController();
  final documentController = TextEditingController();

  final eligibleCourseController = TextEditingController();
  final eligibleCategoryController = TextEditingController();
  final minimumPercentageController = TextEditingController();
  final maximumIncomeController = TextEditingController();

  String? category;
  DateTime? lastDate;

  bool isLoading = true;
  bool isUpdating = false;

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

  // =========================================================
  // LOAD SCHOLARSHIP
  // =========================================================

  @override
  void initState() {
    super.initState();
    _loadScholarship();
  }

  Future<void> _loadScholarship() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("scholarships")
          .doc(widget.scholarshipId)
          .get();

      if (!doc.exists) {
        throw Exception("Scholarship not found");
      }

      final data = doc.data() ?? {};

      titleController.text =
          data["title"]?.toString() ?? "";

      descriptionController.text =
          data["description"]?.toString() ?? "";

      amountController.text =
          data["amount"]?.toString() ?? "";

      eligibilityController.text =
          data["eligibility"]?.toString() ?? "";

      documentController.text =
          data["requiredDocuments"]?.toString() ?? "";

      eligibleCourseController.text =
          data["eligibleCourse"]?.toString() ?? "";

      eligibleCategoryController.text =
          data["eligibleCategory"]?.toString() ?? "";

      minimumPercentageController.text =
          data["minimumPercentage"]?.toString() ?? "";

      maximumIncomeController.text =
          data["maximumAnnualIncome"]?.toString() ?? "";

      final savedCategory =
      data["category"]?.toString();

      if (savedCategory != null &&
          categories.contains(savedCategory)) {
        category = savedCategory;
      }

      final savedDate = data["lastDate"];

      if (savedDate is Timestamp) {
        lastDate = savedDate.toDate();
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to load scholarship: $e",
          ),
        ),
      );
    }
  }

  // =========================================================
  // PICK DATE
  // =========================================================

  Future<void> _pickDate() async {
    final initialDate =
        lastDate ?? DateTime.now();

    final firstDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        lastDate = picked;
      });
    }
  }

  // =========================================================
  // UPDATE SCHOLARSHIP
  // =========================================================

  Future<void> _updateScholarship() async {
    if (isUpdating) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select scholarship category",
          ),
        ),
      );
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

    final percentage = double.tryParse(
      minimumPercentageController.text.trim(),
    );

    if (percentage == null ||
        percentage < 0 ||
        percentage > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Enter percentage between 0 and 100",
          ),
        ),
      );
      return;
    }

    final income = double.tryParse(
      maximumIncomeController.text.trim(),
    );

    if (income == null || income < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Enter a valid annual income",
          ),
        ),
      );
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection("scholarships")
          .doc(widget.scholarshipId)
          .update({
        "title":
        titleController.text.trim(),

        "description":
        descriptionController.text.trim(),

        "amount":
        amountController.text.trim(),

        "category":
        category,

        "eligibility":
        eligibilityController.text.trim(),

        "eligibleCourse":
        eligibleCourseController.text.trim(),

        "eligibleCategory":
        eligibleCategoryController.text.trim(),

        "minimumPercentage":
        percentage,

        "maximumAnnualIncome":
        income,

        "requiredDocuments":
        documentController.text.trim(),

        "lastDate":
        Timestamp.fromDate(lastDate!),

        "updatedAt":
        FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Scholarship updated successfully 🎉",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to update scholarship: $e",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  // =========================================================
  // FIELD
  // =========================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          "Edit Scholarship",
        ),
      ),

      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: Column(
            children: [

              // =================================================
              // TITLE
              // =================================================

              _field(
                controller: titleController,
                label: "Scholarship Title",
                icon: Icons.school,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Enter Scholarship Title";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // DESCRIPTION
              // =================================================

              _field(
                controller: descriptionController,
                label: "Description",
                icon: Icons.description,
                maxLines: 4,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Enter Description";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // AMOUNT
              // =================================================

              _field(
                controller: amountController,
                label: "Scholarship Amount",
                icon: Icons.currency_rupee,
                keyboardType:
                TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Enter Amount";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // CATEGORY
              // =================================================

              DropdownButtonFormField<String>(
                value: category,

                decoration:
                const InputDecoration(
                  labelText: "Category",
                  prefixIcon:
                  Icon(Icons.category),
                ),

                items: categories
                    .map(
                      (item) =>
                      DropdownMenuItem(
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

              // =================================================
              // ELIGIBILITY
              // =================================================

              _field(
                controller: eligibilityController,
                label: "Eligibility",
                icon: Icons.verified_user,
                maxLines: 3,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Enter Eligibility";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =================================================
              // ELIGIBLE COURSE
              // =================================================

              _field(
                controller:
                eligibleCourseController,
                label: "Eligible Course",
                hint:
                "e.g. B.Sc Computer Science",
                icon:
                Icons.menu_book_rounded,
              ),

              const SizedBox(height: 16),

              // =================================================
              // ELIGIBLE CATEGORY
              // =================================================

              _field(
                controller:
                eligibleCategoryController,
                label: "Eligible Category",
                hint:
                "e.g. BC / MBC / SC / ST / OC",
                icon:
                Icons.category_rounded,
              ),

              const SizedBox(height: 16),

              // =================================================
              // MINIMUM PERCENTAGE
              // =================================================

              _field(
                controller:
                minimumPercentageController,
                label: "Minimum Percentage",
                hint: "e.g. 60",
                icon:
                Icons.percent_rounded,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Enter Minimum Percentage";
                  }

                  final percentage =
                  double.tryParse(
                    value.trim(),
                  );

                  if (percentage == null ||
                      percentage < 0 ||
                      percentage > 100) {
                    return "Enter percentage between 0 and 100";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =================================================
              // MAXIMUM ANNUAL INCOME
              // =================================================

              _field(
                controller:
                maximumIncomeController,
                label:
                "Maximum Annual Income",
                hint: "e.g. 250000",
                icon:
                Icons.currency_rupee_rounded,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return
                      "Enter Maximum Annual Income";
                  }

                  final income =
                  double.tryParse(
                    value.trim(),
                  );

                  if (income == null ||
                      income < 0) {
                    return
                      "Enter a valid income";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // REQUIRED DOCUMENTS
              // =================================================

              _field(
                controller:
                documentController,
                label: "Required Documents",
                icon:
                Icons.description_outlined,
                maxLines: 2,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return
                      "Enter Required Documents";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              // =================================================
              // LAST DATE
              // =================================================

              InkWell(
                onTap: _pickDate,
                borderRadius:
                BorderRadius.circular(12),

                child: Container(
                  width: double.infinity,

                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),

                  decoration:
                  BoxDecoration(
                    border: Border.all(
                      color:
                      Colors.grey.shade400,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),

                  child: Row(
                    children: [

                      const Icon(
                        Icons.calendar_month,
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Text(
                        lastDate == null
                            ? "Select Last Date"
                            : "${lastDate!.day.toString().padLeft(2, '0')}/"
                            "${lastDate!.month.toString().padLeft(2, '0')}/"
                            "${lastDate!.year}",

                        style:
                        AppTextStyles.subtitle,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // UPDATE BUTTON
              // =================================================

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.primary,
                    foregroundColor:
                    Colors.white,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),

                  onPressed:
                  isUpdating
                      ? null
                      : _updateScholarship,

                  child: isUpdating
                      ? const SizedBox(
                    width: 24,
                    height: 24,

                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      Colors.white,
                    ),
                  )
                      : const Text(
                    "Update Scholarship",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    eligibilityController.dispose();
    documentController.dispose();

    eligibleCourseController.dispose();
    eligibleCategoryController.dispose();
    minimumPercentageController.dispose();
    maximumIncomeController.dispose();

    super.dispose();
  }
}