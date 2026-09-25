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

  final minimumPercentageController = TextEditingController();
  final maximumIncomeController = TextEditingController();
  final benefitsController = TextEditingController();
  final selectionProcessController = TextEditingController();

  final List<String> selectedCourses = [];
  final List<String> selectedCategories = [];
  final List<String> selectedDocuments = [];

  final List<String> documentOptions = [
    "Aadhaar Card",
    "Income Certificate",
    "Community Certificate",
    "Bonafide Certificate",
    "Marksheet/Transcript",
    "Bank Passbook",
    "Passport Photo",
    "Fee Receipt",
  ];
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

  /// Strips anything that isn't a digit or a decimal point, so values typed
  /// naturally like "60%" or "3,00,000" or "₹2,50,000" still parse correctly.
  String _sanitizeNumber(String value) {
    return value.replaceAll(RegExp(r'[^0-9.]'), '');
  }

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

  /// Fills [target] from a Firestore field that may be the newer
  /// List<dynamic> (multi-select) or an older legacy single String value.
  /// Empty/missing field → left empty, which our chip UI treats as "All".
  void _loadIntoSelection(dynamic field, List<String> target) {
    target.clear();
    if (field == null) return;

    if (field is List) {
      target.addAll(field.map((e) => e.toString()).where((e) => e.isNotEmpty));
    } else {
      final asString = field.toString().trim();
      if (asString.isNotEmpty) target.add(asString);
    }
  }

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

      // eligibleCourse/eligibleCategory/requiredDocuments may be the newer
      // List<String> or an older legacy single String — normalize either
      // into our chip lists.
      _loadIntoSelection(data["eligibleCourse"], selectedCourses);
      _loadIntoSelection(data["eligibleCategory"], selectedCategories);
      _loadIntoSelection(data["requiredDocuments"], selectedDocuments);

      // If a loaded course is actually a specialization (e.g. "Computer
      // Science"), auto-expand its parent course chip so it's visible.
      for (final entry in courseSpecializations.entries) {
        if (entry.value.any(selectedCourses.contains)) {
          expandedCourses.add(entry.key);
        }
      }

      benefitsController.text =
          data["benefits"]?.toString() ?? "";

      selectionProcessController.text =
          data["selectionProcess"]?.toString() ?? "";

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
      _sanitizeNumber(minimumPercentageController.text.trim()),
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
      _sanitizeNumber(maximumIncomeController.text.trim()),
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
        selectedCourses.contains("All") ? <String>[] : selectedCourses,

        "eligibleCategory":
        selectedCategories.contains("All") ? <String>[] : selectedCategories,

        "minimumPercentage":
        percentage,

        "maximumAnnualIncome":
        income,

        "benefits":
        benefitsController.text.trim(),

        "selectionProcess":
        selectionProcessController.text.trim(),

        "requiredDocuments":
        selectedDocuments,

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
                    if (isExpanded) {
                      expandedCourses.remove(course);
                    } else {
                      expandedCourses.add(course);
                    }
                  } else {
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

  /// A labeled group of selectable chips. Tapping "All" clears every other
  /// selection; tapping any other chip while "All" is selected removes
  /// "All" first.
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

  /// Required Documents chip selector: standard options + any custom
  /// document names added via the "+ Add other" dialog, which are shown
  /// as their own (always-selected) chips since they aren't in
  /// [documentOptions].
  Widget _buildDocumentSelector() {
    final customDocs = selectedDocuments
        .where((doc) => !documentOptions.contains(doc))
        .toList();

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
                onSelected: (bool value) {
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

            ...customDocs.map((doc) {
              return FilterChip(
                label: Text(doc),
                selected: true,
                onSelected: (_) {
                  setState(() {
                    selectedDocuments.remove(doc);
                  });
                },
                selectedColor: AppColors.primary.withOpacity(0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.primary),
                ),
                backgroundColor: Colors.white,
              );
            }),

            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text("Add other"),
              onPressed: _showAddDocumentDialog,
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

  Future<void> _showAddDocumentDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Document"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "e.g. Migration Certificate",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && !selectedDocuments.contains(result)) {
      setState(() {
        selectedDocuments.add(result);
      });
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

              _buildCourseSelector(),

              const SizedBox(height: 18),

              _buildMultiSelectSection(
                title: "Eligible Category",
                icon: Icons.category_rounded,
                options: categoryOptions,
                selected: selectedCategories,
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
                    _sanitizeNumber(value.trim()),
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
                    _sanitizeNumber(value.trim()),
                  );

                  if (income == null ||
                      income < 0) {
                    return
                      "Enter a valid income";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =================================================
              // BENEFITS
              // =================================================

              _field(
                controller: benefitsController,
                label: "Benefits",
                hint: "e.g. Full tuition fee waiver, monthly stipend of ₹2,000, mentorship program",
                icon: Icons.card_giftcard_rounded,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter Benefits";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =================================================
              // SELECTION PROCESS
              // =================================================

              _field(
                controller: selectionProcessController,
                label: "Selection Process",
                hint: "e.g. Application screening, document verification, merit-based shortlisting",
                icon: Icons.fact_check_rounded,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter Selection Process";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // REQUIRED DOCUMENTS
              // =================================================

              _buildDocumentSelector(),

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

    minimumPercentageController.dispose();
    maximumIncomeController.dispose();
    benefitsController.dispose();
    selectionProcessController.dispose();

    super.dispose();
  }
}