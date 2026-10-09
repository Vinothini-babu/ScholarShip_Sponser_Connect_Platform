import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/animated_bubbles.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';

class SponsorSignupScreen extends StatefulWidget {
  const SponsorSignupScreen({super.key});

  @override
  State<SponsorSignupScreen> createState() => _SponsorSignupScreenState();
}

class _SponsorSignupScreenState extends State<SponsorSignupScreen> {
  // ------------------------------------------------------------
  // Controllers
  // ------------------------------------------------------------

  final _formKey = GlobalKey<FormState>();

  final TextEditingController organizationController =
  TextEditingController();

  final TextEditingController registrationController =
  TextEditingController();

  final TextEditingController districtController =
  TextEditingController();

  final TextEditingController contactNameController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController mobileController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final TextEditingController confirmPasswordController =
  TextEditingController();

  // ------------------------------------------------------------
  // State
  // ------------------------------------------------------------

  String? selectedState;

  PlatformFile? registrationCertificate;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  bool agreeToTerms = false;

  bool isLoading = false;

  // ------------------------------------------------------------
  // Constants
  // ------------------------------------------------------------

  final List<String> states = const [
    'Tamil Nadu',
    'Kerala',
    'Karnataka',
    'Andhra Pradesh',
    'Telangana',
    'Puducherry',
    'Maharashtra',
    'Delhi',
    'Other',
  ];

  // ------------------------------------------------------------
  // Dispose
  // ------------------------------------------------------------

  @override
  void dispose() {
    organizationController.dispose();
    registrationController.dispose();
    districtController.dispose();
    contactNameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // Cloudinary upload (registration certificate)
  //
  // Use the SAME cloud name + unsigned upload preset that the student
  // apply flow already uses.
  // ------------------------------------------------------------

  static const String _cloudName = 'YOUR_CLOUD_NAME';
  static const String _uploadPreset = 'YOUR_UPLOAD_PRESET';

  Future<String> _uploadProofToCloudinary(PlatformFile file) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset;

    final String? path = file.path;
    if (path == null || path.isEmpty) {
      throw Exception('Unable to read the selected file.');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        path,
        filename: file.name,
      ),
    );

    final response = await http.Response.fromStream(await request.send());
    final Map<String, dynamic> body =
    jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final msg = (body['error'] is Map)
          ? body['error']['message']?.toString()
          : null;
      throw Exception(msg ?? 'Upload failed (${response.statusCode})');
    }

    final url = body['secure_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('Upload succeeded but no URL was returned.');
    }
    return url;
  }

  // ------------------------------------------------------------
  // File Picker
  // ------------------------------------------------------------

  Future<void> pickRegistrationCertificate() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
        ],
      );

      if (file != null) {
        setState(() {
          registrationCertificate = file;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to select file: $e',
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // Create Sponsor Account
  // ------------------------------------------------------------

  Future<void> createSponsorAccount() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your state.'),
        ),
      );
      return;
    }

    if (registrationCertificate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your registration certificate.'),
        ),
      );
      return;
    }

    if (!agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms & Conditions and Privacy Policy.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // ==========================================================
      // FIREBASE SPONSOR ACCOUNT CREATION
      // ==========================================================

      // Upload proof first so the admin can open it from any computer
      final String proofUrl =
      await _uploadProofToCloudinary(registrationCertificate!);

      final AuthService authService = AuthService();

      await authService.signUp(
        name: contactNameController.text.trim(),
        email: emailController.text.trim().replaceFirst(
          RegExp(r'^mailto:', caseSensitive: false),
          '',
        ),
        mobile: mobileController.text.trim(),
        password: passwordController.text,
        role: 'sponsor',
        state: selectedState!,
        district: districtController.text.trim(),
        organizationName: organizationController.text.trim(),
        registrationNumber: registrationController.text.trim(),
        proofDocumentUrl: proofUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Sponsor account created successfully.',
          ),
        ),
      );

      // Firebase signUp leaves the newly-created user signed in.
      // Sign out so the sponsor can use the normal Login screen.
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // Shared field styling — identical to the student signup screen
  // ------------------------------------------------------------

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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
    );
  }

  TextStyle get _inputStyle => AppTextStyles.subtitle.copyWith(
    color: AppColors.textPrimary,
    fontSize: 15,
  );

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

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: _inputStyle,
      decoration: _fieldDecoration(
        hint: hint,
        icon: icon,
        suffixIcon: suffixIcon,
      ),
    );
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Navy gradient header — matches login/signup/splash/role screens
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
                        "Create Sponsor Account",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Register your organization to provide scholarships",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating bubbles (animated background effect)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    child: const AnimatedBubbles(),
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

                // Back arrow — only shown when there is a screen to go back to
                if (Navigator.canPop(context))
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 12,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: "Back",
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                      ),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 24,
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ==============================
                            // ORGANIZATION DETAILS
                            // ==============================
                            const _SectionHeader(
                              icon: Icons.business_rounded,
                              title: "Organization Details",
                            ),
                            const SizedBox(height: 16),

                            _textField(
                              controller: organizationController,
                              hint: "Organization / Trust Name",
                              icon: Icons.business_rounded,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter organization name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            _textField(
                              controller: registrationController,
                              hint: "Registration / PAN Number",
                              icon: Icons.badge_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter registration / PAN number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            _pair(
                              isWide,
                              DropdownButtonFormField<String>(
                                value: selectedState,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.textSecondary),
                                style: _inputStyle,
                                decoration: _fieldDecoration(
                                  hint: "State",
                                  icon: Icons.map_outlined,
                                ),
                                items: states
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (value) => setState(() => selectedState = value),
                              ),
                              _textField(
                                controller: districtController,
                                hint: "District / City",
                                icon: Icons.location_city_outlined,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter district / city';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFilePicker(),

                            const SizedBox(height: 28),

                            // ==============================
                            // CONTACT PERSON
                            // ==============================
                            const _SectionHeader(
                              icon: Icons.person_outline_rounded,
                              title: "Contact Person",
                            ),
                            const SizedBox(height: 16),

                            _textField(
                              controller: contactNameController,
                              hint: "Contact Person Name",
                              icon: Icons.person_outline_rounded,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter contact person name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            _pair(
                              isWide,
                              _textField(
                                controller: emailController,
                                hint: "Email Address",
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter email';
                                  }

                                  final emailRegex = RegExp(
                                    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                                  );

                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Enter valid email';
                                  }

                                  return null;
                                },
                              ),
                              _textField(
                                controller: mobileController,
                                hint: "Mobile Number",
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter mobile number';
                                  }

                                  if (value.trim().length != 10) {
                                    return 'Enter 10 digit number';
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ==============================
                            // ACCOUNT SECURITY
                            // ==============================
                            const _SectionHeader(
                              icon: Icons.lock_outline_rounded,
                              title: "Account Security",
                            ),
                            const SizedBox(height: 16),

                            _pair(
                              isWide,
                              _textField(
                                controller: passwordController,
                                hint: "Password",
                                icon: Icons.lock_outline_rounded,
                                obscureText: obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => obscurePassword = !obscurePassword),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter password';
                                  }

                                  if (value.length < 6) {
                                    return 'Minimum 6 characters';
                                  }

                                  return null;
                                },
                              ),
                              _textField(
                                controller: confirmPasswordController,
                                hint: "Confirm Password",
                                icon: Icons.lock_outline_rounded,
                                obscureText: obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                          () => obscureConfirmPassword = !obscureConfirmPassword),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirm password';
                                  }

                                  if (value != passwordController.text) {
                                    return 'Passwords do not match';
                                  }

                                  return null;
                                },
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
                                    value: agreeToTerms,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5)),
                                    onChanged: (value) =>
                                        setState(() => agreeToTerms = value ?? false),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => agreeToTerms = !agreeToTerms),
                                    child: RichText(
                                      text: TextSpan(
                                        style: AppTextStyles.subtitle.copyWith(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                        ),
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
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                    const TermsConditionsScreen()),
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
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                    const PrivacyPolicyScreen()),
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
                                onPressed: isLoading ? null : createSponsorAccount,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  "Create Sponsor Account",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
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

  // ------------------------------------------------------------
  // Registration certificate picker (styled like the other fields)
  // ------------------------------------------------------------

  Widget _buildFilePicker() {
    final bool hasFile = registrationCertificate != null;

    return InkWell(
      onTap: pickRegistrationCertificate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasFile
                ? AppColors.success.withOpacity(0.6)
                : AppColors.textSecondary.withOpacity(0.15),
            width: hasFile ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (hasFile ? AppColors.success : AppColors.primary).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasFile ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                color: hasFile ? AppColors.success : AppColors.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? registrationCertificate!.name : "Upload Registration Certificate",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(
                      color: hasFile ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: hasFile ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasFile ? "Certificate selected successfully" : "PDF, JPG or PNG",
                    style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.cloud_upload_outlined,
              color: AppColors.primary,
              size: 22,
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
        Expanded(
          child: Divider(
            color: AppColors.textSecondary.withOpacity(0.15),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}