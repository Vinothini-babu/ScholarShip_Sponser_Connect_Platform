import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class AddScholarshipScreen extends StatefulWidget {
  const AddScholarshipScreen({super.key});

  @override
  State<AddScholarshipScreen> createState() =>
      _AddScholarshipScreenState();
}

class _AddScholarshipScreenState
    extends State<AddScholarshipScreen> {

  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  final eligibilityController = TextEditingController();
  final List<String> selectedCourses = [];
  final List<String> selectedCategories = [];
  final List<String> selectedDocuments = [];
  final Set<String> expandedCourses = {}; // which courses currently show their specialization chips

  final List<String> courseOptions = [
    "All",
    "B.Sc",
    "B.A",
    "B.Com",
    "B.E",
    "B.Tech",
    "BBA",
    "BCA",
    "M.Sc",
    "MBA",
    "MCA",
    "Diploma",
  ];

  /// Courses that have specific specializations. Tapping one of these in
  /// the main chip row expands this list instead of selecting the course
  /// itself — the actual eligible-course value stored is the specialization
  /// (e.g. "Computer Science"), not the parent degree.
  /// Courses NOT listed here (e.g. BCA) are selected directly, no expansion.
  final Map<String, List<String>> courseSpecializations = {
    "B.Sc": ["Computer Science", "Information Technology", "Cyber Security", "AI & ML"],
    "B.Com": ["CA", "PA", "IT"],
  };

  final List<String> categoryOptions = [
    "All",
    "OC",
    "BC",
    "MBC",
    "SC",
    "ST",
    "Minority",
  ];

  /// Standard document types a sponsor can require. "Other" opens a small
  /// dialog to add a custom document name not in this list.
  final List<String> documentOptions = [
    "Aadhaar Card",
    "Income Certificate",
    "Community Certificate",
    "Bonafide Certificate",
    "Marksheet / Transcript",
    "Bank Passbook",
    "Passport Size Photo",
    "Fee Receipt",
  ];
  final minimumPercentageController = TextEditingController();
  final maximumIncomeController = TextEditingController();
  final benefitsController = TextEditingController();
  final selectionProcessController = TextEditingController();

  String? category;
  DateTime? lastDate;

  bool isLoading = false;

  /// Strips anything that isn't a digit or a decimal point, so values typed
  /// naturally like "60%" or "3,00,000" or "₹2,50,000" still parse correctly.
  String _sanitizeNumber(String value) {
    return value.replaceAll(RegExp(r'[^0-9.]'), '');
  }

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

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text("Add Scholarship"),
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

              _buildCourseSelector(),

              const SizedBox(height: 18),

              _buildMultiSelectSection(
                title: "Eligible Category",
                icon: Icons.category_rounded,
                options: categoryOptions,
                selected: selectedCategories,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: minimumPercentageController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Minimum Percentage",
                  hintText: "e.g. 60",
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Minimum Percentage";
                  }

                  final percentage = double.tryParse(_sanitizeNumber(value));

                  if (percentage == null ||
                      percentage < 0 ||
                      percentage > 100) {
                    return "Enter percentage between 0 and 100";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: maximumIncomeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Maximum Annual Income",
                  hintText: "e.g. 250000",
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Maximum Annual Income";
                  }

                  final income = double.tryParse(_sanitizeNumber(value));

                  if (income == null || income < 0) {
                    return "Enter a valid income";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: benefitsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Benefits",
                  hintText: "e.g. Full tuition fee waiver, monthly stipend of ₹2,000, mentorship program",
                  prefixIcon: Icon(Icons.card_giftcard_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Benefits";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: selectionProcessController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Selection Process",
                  hintText: "e.g. Application screening, document verification, merit-based shortlisting",
                  prefixIcon: Icon(Icons.fact_check_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Selection Process";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              _buildDocumentSelector(),

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

                    if (selectedCourses.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Select at least one eligible course (or 'All')",
                          ),
                        ),
                      );
                      return;
                    }

                    if (selectedCategories.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Select at least one eligible category (or 'All')",
                          ),
                        ),
                      );
                      return;
                    }

                    if (selectedDocuments.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Select at least one required document",
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    final user = FirebaseAuth.instance.currentUser!;

                    await FirebaseFirestore.instance
                        .collection("scholarships")
                        .add({
                      "title": titleController.text.trim(),
                      "description": descriptionController.text.trim(),
                      "amount": amountController.text.trim(),
                      "category": category,

                      "eligibility": eligibilityController.text.trim(),

                      // 👇 New eligibility details
                      // "All" (or empty selection) means open to every course/category —
                      // stored as an empty list so eligibility_utils.dart treats it as universal.
                      "eligibleCourse": selectedCourses.contains("All")
                          ? <String>[]
                          : selectedCourses,

                      "eligibleCategory": selectedCategories.contains("All")
                          ? <String>[]
                          : selectedCategories,

                      "minimumPercentage":
                      double.tryParse(
                        _sanitizeNumber(minimumPercentageController.text.trim()),
                      ) ?? 0,

                      "maximumAnnualIncome":
                      double.tryParse(
                        _sanitizeNumber(maximumIncomeController.text.trim()),
                      ) ?? 0,

                      "benefits": benefitsController.text.trim(),

                      "selectionProcess": selectionProcessController.text.trim(),

                      "requiredDocuments": selectedDocuments,

                      "lastDate":
                      Timestamp.fromDate(lastDate!),

                      "sponsorId": user.uid,
                      "sponsorName": user.email,

                      "status": "Active",
                      "createdAt": FieldValue.serverTimestamp(),
                    });

                    setState(() {
                      isLoading = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Scholarship Published Successfully 🎉",
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
                    "Publish Scholarship",
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

  /// Course chips where some courses (per courseSpecializations) expand
  /// into a specialization sub-panel instead of being selected directly.
  Widget _buildCourseSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text("Eligible Course", style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: courseOptions.map((course) {
            final specs = courseSpecializations[course];
            final bool hasSpecs = specs != null && specs.isNotEmpty;
            final bool isExpanded = expandedCourses.contains(course);

            // A course with specializations shows "selected" once any of
            // its specializations are chosen — the parent itself is never
            // stored, only the leaf specialization.
            final bool isSelected = course == "All"
                ? selectedCourses.contains("All")
                : hasSpecs
                ? specs!.any(selectedCourses.contains)
                : selectedCourses.contains(course);

            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(course),
                  if (hasSpecs) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  if (course == "All") {
                    selectedCourses
                      ..clear()
                      ..add("All");
                    expandedCourses.clear();
                    return;
                  }

                  selectedCourses.remove("All");

                  if (hasSpecs) {
                    // Tapping a course-with-specializations only
                    // expands/collapses its sub-panel.
                    if (isExpanded) {
                      expandedCourses.remove(course);
                    } else {
                      expandedCourses.add(course);
                    }
                  } else {
                    // No specializations for this course — select it directly.
                    if (selectedCourses.contains(course)) {
                      selectedCourses.remove(course);
                    } else {
                      selectedCourses.add(course);
                    }
                  }
                });
              },
              selectedColor: AppColors.primary.withOpacity(0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
              backgroundColor: Colors.white,
            );
          }).toList(),
        ),

        // Specialization sub-panels for every currently expanded course.
        for (final course in expandedCourses)
          if (courseSpecializations[course] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Choose $course specialization",
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: courseSpecializations[course]!.map((spec) {
                        final bool isSpecSelected = selectedCourses.contains(spec);
                        return FilterChip(
                          label: Text(spec, style: const TextStyle(fontSize: 12.5)),
                          selected: isSpecSelected,
                          onSelected: (bool value) {
                            setState(() {
                              selectedCourses.remove("All");
                              if (value) {
                                selectedCourses.add(spec);
                              } else {
                                selectedCourses.remove(spec);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSpecSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSpecSelected ? AppColors.primary : Colors.grey.shade300,
                            ),
                          ),
                          backgroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// Required-document picker — same chip pattern as courses/categories,
  /// plus an "+ Other" chip that opens a dialog to add a custom document
  /// name that isn't in the standard list.
  Widget _buildDocumentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text("Required Documents", style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Students will only be asked to upload the documents you select here.",
          style: AppTextStyles.subtitle.copyWith(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...documentOptions.map((doc) {
              final bool isSelected = selectedDocuments.contains(doc);
              return FilterChip(
                label: Text(doc),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      selectedDocuments.add(doc);
                    } else {
                      selectedDocuments.remove(doc);
                    }
                  });
                },
                selectedColor: AppColors.primary.withOpacity(0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  ),
                ),
                backgroundColor: Colors.white,
              );
            }),

            // Any custom documents the sponsor has typed in, shown as
            // removable chips alongside the standard ones.
            ...selectedDocuments.where((d) => !documentOptions.contains(d)).map((custom) {
              return InputChip(
                label: Text(custom),
                selected: true,
                onSelected: (_) {},
                onDeleted: () => setState(() => selectedDocuments.remove(custom)),
                selectedColor: AppColors.primary.withOpacity(0.15),
                labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.primary),
                ),
                backgroundColor: Colors.white,
              );
            }),

            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16),
              label: const Text("Add other"),
              onPressed: _showAddCustomDocumentDialog,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              backgroundColor: Colors.white,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showAddCustomDocumentDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Required Document"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "e.g. Migration Certificate"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && !selectedDocuments.contains(result)) {
      setState(() => selectedDocuments.add(result));
    }
  }

  /// A labeled group of selectable chips. Tapping "All" clears every other
  /// selection (since "open to everyone" and "restricted to X" are
  /// mutually exclusive); tapping any other chip while "All" is selected
  /// removes "All" first.
  Widget _buildMultiSelectSection({
    required String title,
    required IconData icon,
    required List<String> options,
    required List<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final bool isSelected = selected.contains(option);

            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (bool value) {
                setState(() {
                  if (option == "All") {
                    selected
                      ..clear()
                      ..add("All");
                  } else {
                    selected.remove("All");
                    if (value) {
                      selected.add(option);
                    } else {
                      selected.remove(option);
                    }
                  }
                });
              },
              selectedColor: AppColors.primary.withOpacity(0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
              backgroundColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    eligibilityController.dispose();

    minimumPercentageController.dispose();
    maximumIncomeController.dispose();
    benefitsController.dispose();
    selectionProcessController.dispose();

    super.dispose();
  }
}