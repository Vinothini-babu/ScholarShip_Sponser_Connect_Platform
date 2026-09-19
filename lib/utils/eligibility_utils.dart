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

/// Normalizes an `eligibleCourse` / `eligibleCategory` field into a
/// lowercase, trimmed list — regardless of whether it was saved as the
/// newer List<String> (multi-select) or an older single String value
/// (legacy scholarships created before multi-select was added).
List<String> _normalizeToList(dynamic field) {
  if (field == null) return [];

  if (field is List) {
    return field
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  final asString = field.toString().trim().toLowerCase();
  return asString.isEmpty ? [] : [asString];
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

  final requiredCourses = _normalizeToList(scholarship["eligibleCourse"]);

  final requiredCategories = _normalizeToList(scholarship["eligibleCategory"]);

  final minimumPercentage = parseNumericValue(scholarship["minimumPercentage"]);

  final maximumIncome = parseNumericValue(scholarship["maximumAnnualIncome"]);

  final courseEligible = requiredCourses.isEmpty ||
      requiredCourses.contains("all") ||
      requiredCourses.contains(studentCourse);

  final categoryEligible = requiredCategories.isEmpty ||
      requiredCategories.contains("all") ||
      requiredCategories.contains(studentCategory);

  final percentageEligible = studentPercentage >= minimumPercentage;

  final incomeEligible = studentIncome <= maximumIncome;

  final reasons = <String>[];

  if (!courseEligible) {
    reasons.add(
      "Open only to ${requiredCourses.join(', ')} students. Your course: ${student["course"] ?? "Not set"}.",
    );
  }

  if (!categoryEligible) {
    reasons.add(
      "Open only to ${requiredCategories.join(', ')} category. Your category: ${student["category"] ?? "Not set"}.",
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