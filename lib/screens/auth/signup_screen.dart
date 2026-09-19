import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ---- Personal details ----
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController districtController = TextEditingController();

  // ---- Academic details ----
  final TextEditingController collegeController = TextEditingController();
  final TextEditingController courseController = TextEditingController();
  final TextEditingController rollNumberController = TextEditingController();
  final TextEditingController incomeController = TextEditingController();

  // ---- Account security ----
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  DateTime? _dob;
  String? _yearOfStudy;
  String? _category;
  String? _selectedState;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;

  final List<String> _yearOptions = ["1st Year", "2nd Year", "3rd Year", "4th Year", "Other"];
  final List<String> _categoryOptions = ["General", "OBC", "MBC", "SC", "ST", "EWS", "Other"];

  final List<String> _stateOptions = [
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chhattisgarh",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal",
    "Andaman and Nicobar Islands",
    "Chandigarh",
    "Dadra and Nagar Haveli and Daman and Diu",
    "Delhi",
    "Jammu and Kashmir",
    "Ladakh",
    "Lakshadweep",
    "Puducherry",
  ];

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    dobController.dispose();
    districtController.dispose();
    collegeController.dispose();
    courseController.dispose();
    rollNumberController.dispose();
    incomeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 60),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dob = picked;
        dobController.text = "${picked.day.toString().padLeft(2, '0')}/"
            "${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _handleSignup() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        mobileController.text.isEmpty ||
        dobController.text.isEmpty ||
        _selectedState == null ||
        districtController.text.isEmpty ||
        collegeController.text.isEmpty ||
        courseController.text.isEmpty ||
        rollNumberController.text.isEmpty ||
        incomeController.text.isEmpty ||
        _yearOfStudy == null ||
        _category == null ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please accept the Terms & Conditions to continue")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // NOTE: AuthService.signUp needs to accept these additional named
      // parameters (dob, state, district, rollNumber, annualIncome,
      // yearOfStudy, category) and write them to the student's Firestore
      // profile alongside the existing fields.
      await _authService.signUp(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        mobile: mobileController.text.trim(),
        college: collegeController.text.trim(),
        course: courseController.text.trim(),
        password: passwordController.text.trim(),
        role: "student",
        dob: _dob,
        state: _selectedState,
        district: districtController.text.trim(),
        rollNumber: rollNumberController.text.trim(),
        annualIncome: incomeController.text.trim(),
        yearOfStudy: _yearOfStudy,
        category: _category,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account Created Successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.subtitle.copyWith(fontSize: 15),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
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

  /// Lays two fields side by side on wide screens, stacked on narrow ones.
  Widget _pair(bool isWide, Widget a, Widget b) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ],
      );
    }
    return Column(
      children: [
        a,
        const SizedBox(height: 16),
        b,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Navy gradient header — matches login/splash/role screens
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.of(context).padding.top + 26,
                    24,
                    30,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.88)],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const AppLogo(size: 48),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Create Account",
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Join Scholarship Sponsor Connect",
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  top: -size.width * 0.15,
                  right: -size.width * 0.18,
                  child: Container(
                    width: size.width * 0.5,
                    height: size.width * 0.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withOpacity(0.10),
                    ),
                  ),
                ),
              ],
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 720;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ==============================
                          // PERSONAL DETAILS
                          // ==============================
                          _SectionHeader(icon: Icons.badge_outlined, title: "Personal Details"),
                          const SizedBox(height: 16),

                          TextField(
                            controller: nameController,
                            style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                            decoration: _fieldDecoration(hint: "Full Name", icon: Icons.person_outline_rounded),
                          ),
                          const SizedBox(height: 16),

                          _pair(
                            isWide,
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(hint: "Email Address", icon: Icons.email_outlined),
                            ),
                            TextField(
                              controller: mobileController,
                              keyboardType: TextInputType.phone,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(hint: "Mobile Number", icon: Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _pair(
                            isWide,
                            TextField(
                              controller: dobController,
                              readOnly: true,
                              onTap: _pickDob,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(
                                hint: "Date of Birth",
                                icon: Icons.cake_outlined,
                                suffixIcon: Icon(Icons.calendar_today_rounded,
                                    color: AppColors.textSecondary, size: 18),
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              value: _category,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(hint: "Category", icon: Icons.groups_outlined),
                              items: _categoryOptions
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (value) => setState(() => _category = value),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _pair(
                            isWide,
                            DropdownButtonFormField<String>(
                              value: _selectedState,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(hint: "State", icon: Icons.map_outlined),
                              items: _stateOptions
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (value) => setState(() => _selectedState = value),
                            ),
                            TextField(
                              controller: districtController,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration:
                              _fieldDecoration(hint: "District / City", icon: Icons.location_city_outlined),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ==============================
                          // ACADEMIC DETAILS
                          // ==============================
                          _SectionHeader(icon: Icons.school_outlined, title: "Academic Details"),
                          const SizedBox(height: 16),

                          TextField(
                            controller: collegeController,
                            style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                            decoration: _fieldDecoration(hint: "College Name", icon: Icons.account_balance_outlined),
                          ),
                          const SizedBox(height: 16),

                          _pair(
                            isWide,
                            TextField(
                              controller: courseController,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(hint: "Course", icon: Icons.menu_book_outlined),
                            ),
                            DropdownButtonFormField<String>(
                              value: _yearOfStudy,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(hint: "Year of Study", icon: Icons.timeline_outlined),
                              items: _yearOptions
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                                  .toList(),
                              onChanged: (value) => setState(() => _yearOfStudy = value),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _pair(
                            isWide,
                            TextField(
                              controller: rollNumberController,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration:
                              _fieldDecoration(hint: "Roll / Register Number", icon: Icons.badge_outlined),
                            ),
                            TextField(
                              controller: incomeController,
                              keyboardType: TextInputType.number,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(
                                  hint: "Annual Family Income (₹)", icon: Icons.currency_rupee_rounded),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ==============================
                          // ACCOUNT SECURITY
                          // ==============================
                          _SectionHeader(icon: Icons.lock_outline_rounded, title: "Account Security"),
                          const SizedBox(height: 16),

                          _pair(
                            isWide,
                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(
                                hint: "Password",
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                ),
                              ),
                            ),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: obscureConfirmPassword,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration: _fieldDecoration(
                                hint: "Confirm Password",
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==============================
                          // TERMS & CONDITIONS
                          // ==============================
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _agreedToTerms,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                                  child: RichText(
                                    text: TextSpan(
                                      style:
                                      AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 13),
                                      children: [
                                        const TextSpan(text: "I agree to the "),
                                        TextSpan(
                                          text: "Terms & Conditions",
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            decoration: TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
                                            ),
                                        ),
                                        const TextSpan(text: " and "),
                                        TextSpan(
                                          text: "Privacy Policy",
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            decoration: TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                                            ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                                  : const Text(
                                "Create Account",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// SECTION HEADER — small label + divider, groups related fields
// ==============================
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTextStyles.title.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppColors.textSecondary.withOpacity(0.15), thickness: 1)),
      ],
    );
  }
}