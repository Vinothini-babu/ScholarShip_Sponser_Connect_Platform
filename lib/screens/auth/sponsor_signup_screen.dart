
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';

class SponsorSignupScreen extends StatefulWidget {
  const SponsorSignupScreen({super.key});

  @override
  State<SponsorSignupScreen> createState() => _SponsorSignupScreenState();
}

class _SponsorSignupScreenState extends State<SponsorSignupScreen> {
  // ---- Contact & organization ----
  final TextEditingController nameController = TextEditingController();
  final TextEditingController organizationController = TextEditingController();
  final TextEditingController registrationController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController districtController = TextEditingController();

  // ---- Account security ----
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  String? _selectedState;
  PlatformFile? _proofDocument;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;

  final List<String> _stateOptions = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa",
    "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala",
    "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland",
    "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura",
    "Uttar Pradesh", "Uttarakhand", "West Bengal", "Andaman and Nicobar Islands",
    "Chandigarh", "Dadra and Nagar Haveli and Daman and Diu", "Delhi",
    "Jammu and Kashmir", "Ladakh", "Lakshadweep", "Puducherry",
  ];

  // Same document-validation vocabulary used across the app's upload
  // screens (upload_documents_screen.dart / scholarship_application_screen.dart).
  static const List<String> _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
  static const int _minFileSizeBytes = 10 * 1024;
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;
  static const List<String> _suspiciousNameKeywords = [
    'test', 'sample', 'dummy', 'fake', 'temp', 'untitled',
  ];
  static const List<String> _screenshotNameKeywords = [
    'screenshot', 'screen_shot', 'screenrecording', 'img_wa', 'snip', 'capture',
  ];

  @override
  void dispose() {
    nameController.dispose();
    organizationController.dispose();
    registrationController.dispose();
    emailController.dispose();
    mobileController.dispose();
    districtController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickProofDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (file == null) return;

    final error = await _validateFile(file);
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }

    setState(() => _proofDocument = file);
  }

  Future<String?> _validateFile(PlatformFile file) async {
    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';

    if (!_allowedExtensions.contains(ext)) {
      return "Only PDF, JPG or PNG files are accepted.";
    }

    final int size = file.lengthSync() ?? await file.length() ?? 0;

    if (size < _minFileSizeBytes) {
      return "This file looks too small to be a real document. Please upload the original.";
    }
    if (size > _maxFileSizeBytes) {
      return "File is too large (max 10 MB). Please upload a smaller scan or photo.";
    }
    if (_suspiciousNameKeywords.any((k) => name.contains(k))) {
      return "This file name looks like a placeholder. Please upload your actual registration certificate.";
    }
    if (_screenshotNameKeywords.any((k) => name.contains(k))) {
      return "Screenshots aren't accepted. Please upload the original document file.";
    }
    return null;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppColors.error : null,
        content: Text(message),
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (nameController.text.isEmpty ||
        organizationController.text.isEmpty ||
        registrationController.text.isEmpty ||
        emailController.text.isEmpty ||
        mobileController.text.isEmpty ||
        _selectedState == null ||
        districtController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showSnack("Please fill all fields", isError: true);
      return;
    }

    if (_proofDocument == null) {
      _showSnack("Please upload your registration certificate", isError: true);
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showSnack("Passwords do not match", isError: true);
      return;
    }

    if (!_agreedToTerms) {
      _showSnack("Please accept the Terms & Conditions to continue", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // NOTE: proof document is stored as a local file path for now — same
      // limitation as the student apply flow, until Firebase Storage
      // upload is wired in across the app.
      await _authService.signUp(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        mobile: mobileController.text.trim(),
        password: passwordController.text.trim(),
        role: "sponsor",
        state: _selectedState,
        district: districtController.text.trim(),
        organizationName: organizationController.text.trim(),
        registrationNumber: registrationController.text.trim(),
        proofDocumentUrl: _proofDocument!.path ?? "",
      );

      if (!mounted) return;
      _showSnack("Sponsor account created successfully");
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
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
        children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)],
      );
    }
    return Column(children: [a, const SizedBox(height: 16), b]);
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
                  padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 26, 24, 30),
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
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const AppLogo(size: 48),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Sponsor Sign Up",
                        style: AppTextStyles.heading.copyWith(fontSize: 24, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Partner with Scholarship Sponsor Connect",
                        style: AppTextStyles.subtitle.copyWith(color: Colors.white.withOpacity(0.8)),
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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.secondary.withOpacity(0.10)),
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
                          // ORGANIZATION DETAILS
                          // ==============================
                          _SectionHeader(icon: Icons.apartment_rounded, title: "Organization Details"),
                          const SizedBox(height: 16),

                          TextField(
                            controller: organizationController,
                            style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                            decoration: _fieldDecoration(
                                hint: "Organization / Trust Name", icon: Icons.apartment_rounded),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: registrationController,
                            style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                            decoration: _fieldDecoration(
                                hint: "Registration / PAN Number", icon: Icons.badge_outlined),
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
                              items: _stateOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (value) => setState(() => _selectedState = value),
                            ),
                            TextField(
                              controller: districtController,
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                              decoration:
                              _fieldDecoration(hint: "District / City", icon: Icons.location_city_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Proof document upload
                          InkWell(
                            onTap: _pickProofDocument,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _proofDocument != null
                                      ? AppColors.success
                                      : AppColors.textSecondary.withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _proofDocument != null
                                        ? Icons.check_circle_rounded
                                        : Icons.upload_file_rounded,
                                    color: _proofDocument != null ? AppColors.success : AppColors.primary,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _proofDocument?.name ?? "Upload Registration Certificate (PDF, JPG, PNG)",
                                      style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ==============================
                          // CONTACT PERSON
                          // ==============================
                          _SectionHeader(icon: Icons.person_outline_rounded, title: "Contact Person"),
                          const SizedBox(height: 16),

                          TextField(
                            controller: nameController,
                            style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
                            decoration: _fieldDecoration(hint: "Contact Person Name", icon: Icons.person_outline_rounded),
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
                                      style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 13),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                                  : const Text("Create Sponsor Account",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        Text(title, style: AppTextStyles.title.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppColors.textSecondary.withOpacity(0.15), thickness: 1)),
      ],
    );
  }
}