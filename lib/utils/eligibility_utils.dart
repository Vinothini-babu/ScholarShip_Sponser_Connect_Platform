/// Shared eligibility-checking logic for scholarships.
///
/// Used by both EligibleScholarshipsScreen (to filter the list) and the
/// student dashboard (to decide where a "Trending Scholarship" tap should
/// go — Eligible screen if the student qualifies, or the scholarship's own
/// Details screen if they don't).

double parseNumericValue(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString().trim()) ?? 0;
}

class EligibilityResult {
  final bool isEligible;
  final List<String> reasons; // empty when eligible

  const EligibilityResult({
    required this.isEligible,
    required this.reasons,
  });
}

/// Compares a scholarship's requirements against a student's profile.
///
/// [scholarship] and [student] are the raw Firestore maps (e.g. from
/// `doc.data()`), same shape used across the app.
EligibilityResult checkScholarshipEligibility(
    Map<String, dynamic> scholarship,
    Map<String, dynamic> student,
    ) {
  final studentCourse =
  (student["course"] ?? "").toString().trim().toLowerCase();

  final studentCategory =
  (student["category"] ?? "").toString().trim().toLowerCase();

  final studentPercentage = parseNumericValue(student["percentage"]);

  final studentIncome = parseNumericValue(student["annualIncome"]);

  final requiredCourse =
  (scholarship["eligibleCourse"] ?? "").toString().trim().toLowerCase();

  final requiredCategory =
  (scholarship["eligibleCategory"] ?? "").toString().trim().toLowerCase();

  final minimumPercentage = parseNumericValue(scholarship["minimumPercentage"]);

  final maximumIncome = parseNumericValue(scholarship["maximumAnnualIncome"]);

  final courseEligible = requiredCourse.isEmpty ||
      requiredCourse == "all" ||
      studentCourse == requiredCourse;

  final categoryEligible = requiredCategory.isEmpty ||
      requiredCategory == "all" ||
      studentCategory == requiredCategory;

  final percentageEligible = studentPercentage >= minimumPercentage;

  final incomeEligible = studentIncome <= maximumIncome;

  final reasons = <String>[];

  if (!courseEligible) {
    reasons.add(
      "Open only to ${scholarship["eligibleCourse"]} students. Your course: ${student["course"] ?? "Not set"}.",
    );
  }

  if (!categoryEligible) {
    reasons.add(
      "Open only to ${scholarship["eligibleCategory"]} category. Your category: ${student["category"] ?? "Not set"}.",
    );
  }

  if (!percentageEligible) {
    reasons.add(
      "Requires a minimum of ${minimumPercentage.toStringAsFixed(0)}%. Your percentage: ${studentPercentage.toStringAsFixed(0)}%.",
    );
  }

  if (!incomeEligible) {
    reasons.add(
      "Maximum annual income allowed is ₹${maximumIncome.toStringAsFixed(0)}. Your annual income: ₹${studentIncome.toStringAsFixed(0)}.",
    );
  }

  return EligibilityResult(
    isEligible: reasons.isEmpty,
    reasons: reasons,
  );
}

/// Convenience bool-only version, kept for call sites that just need a
/// yes/no (e.g. the filtering `.where(...)` in EligibleScholarshipsScreen).
bool isStudentEligibleForScholarship(
    Map<String, dynamic> scholarship,
    Map<String, dynamic> student,
    ) {
  return checkScholarshipEligibility(scholarship, student).isEligible;
}