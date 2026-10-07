import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';

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

  static const Color primaryColor = Color(0xFF1F3764);
  static const Color primaryDark = Color(0xFF182D54);

  static const Color pageBackground = Color(0xFFF8FAFC);

  static const Color fieldBackground = Colors.white;

  static const Color borderColor = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF172554);

  static const Color textSecondary = Color(0xFF64748B);

  static const Color iconBackground = Color(0xFFEAF0FB);

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
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return _buildDesktopLayout();
          }

          return _buildMobileLayout();
        },
      ),
    );
  }

  // ============================================================
  // DESKTOP LAYOUT
  // ============================================================

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // --------------------------------------------------------
        // LEFT BRANDING PANEL
        // --------------------------------------------------------

        Expanded(
          flex: 42,
          child: _buildBrandingPanel(),
        ),

        // --------------------------------------------------------
        // RIGHT FORM PANEL
        // --------------------------------------------------------

        Expanded(
          flex: 58,
          child: _buildDesktopFormPanel(),
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE LAYOUT
  // ============================================================

  Widget _buildMobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildMobileBranding(),

            _buildMobileFormPanel(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP BRANDING
  // ============================================================

  Widget _buildBrandingPanel() {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        color: primaryColor,
      ),
      child: Stack(
        children: [
          // Decorative circle - top right
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          // Decorative circle - bottom left
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 40,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(
                      size: 150,
                      showWhiteContainer: true,
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'Scholarship Sponsor\nConnect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Partner with us to support\nthe next generation of achievers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFDCE6F8),
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 45),

                    _buildBenefitCard(
                      icon: Icons.school_rounded,
                      title: 'Support Students',
                      description:
                      'Help deserving students continue their education.',
                    ),

                    const SizedBox(height: 14),

                    _buildBenefitCard(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'Create Opportunities',
                      description:
                      'Provide meaningful scholarship opportunities.',
                    ),

                    const SizedBox(height: 14),

                    _buildBenefitCard(
                      icon: Icons.track_changes_rounded,
                      title: 'Make an Impact',
                      description:
                      'Track scholarships and applications easily.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE BRANDING
  // ============================================================

  Widget _buildMobileBranding() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: primaryColor,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              34,
              24,
              32,
            ),
            child: Column(
              children: [
                _buildLogo(
                  size: 105,
                  showWhiteContainer: true,
                ),

                const SizedBox(height: 18),

                const Text(
                  'Scholarship Sponsor Connect',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Partner with us to support the next generation of achievers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFDCE6F8),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _buildLogo({
    required double size,
    required bool showWhiteContainer,
  }) {
    final Widget logo = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (
          context,
          error,
          stackTrace,
          ) {
        return Icon(
          Icons.school_rounded,
          size: size * 0.55,
          color: primaryColor,
        );
      },
    );

    if (!showWhiteContainer) {
      return logo;
    }

    return Container(
      width: size + 28,
      height: size + 28,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: logo,
    );
  }

  // ============================================================
  // BENEFIT CARD
  // ============================================================

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFD1DCF0),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DESKTOP FORM PANEL
  // ============================================================

  Widget _buildDesktopFormPanel() {
    return Container(
      height: double.infinity,
      color: pageBackground,
      child: Column(
        children: [
          _buildFormHeader(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                52,
                28,
                52,
                40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 760,
                  ),
                  child: _buildSignupForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE FORM PANEL
  // ============================================================

  Widget _buildMobileFormPanel() {
    return Container(
      width: double.infinity,
      color: pageBackground,
      padding: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        40,
      ),
      child: _buildSignupForm(),
    );
  }

  // ============================================================
  // FORM HEADER
  // ============================================================

  Widget _buildFormHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        42,
        22,
        42,
        18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: borderColor,
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(
                Icons.arrow_back_rounded,
                color: primaryColor,
                size: 25,
              ),
            ),
          ),

          const SizedBox(width: 14),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Sponsor Account',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),

              SizedBox(height: 3),

              Text(
                'Register your organization to provide scholarship opportunities.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN FORM
  // ============================================================

  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // ORGANIZATION
          // ------------------------------------------------------

          _buildSectionTitle(
            icon: Icons.business_rounded,
            title: 'Organization Details',
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: organizationController,
            label: 'Organization / Trust Name',
            hint: 'Enter organization or trust name',
            icon: Icons.business_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter organization name';
              }

              return null;
            },
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller: registrationController,
            label: 'Registration / PAN Number',
            hint: 'Enter registration or PAN number',
            icon: Icons.badge_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter registration / PAN number';
              }

              return null;
            },
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStateDropdown(),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildTextField(
                  controller: districtController,
                  label: 'District / City',
                  hint: 'Enter district / city',
                  icon: Icons.location_city_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter district / city';
                    }

                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildFilePicker(),

          const SizedBox(height: 30),

          // ------------------------------------------------------
          // CONTACT PERSON
          // ------------------------------------------------------

          _buildSectionTitle(
            icon: Icons.person_rounded,
            title: 'Contact Person',
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: contactNameController,
            label: 'Contact Person Name',
            hint: 'Enter contact person name',
            icon: Icons.person_outline_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter contact person name';
              }

              return null;
            },
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: emailController,
                  label: 'Email Address',
                  hint: 'Enter email address',
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
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildTextField(
                  controller: mobileController,
                  label: 'Mobile Number',
                  hint: 'Enter mobile number',
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
            ],
          ),

          const SizedBox(height: 30),

          // ------------------------------------------------------
          // ACCOUNT SECURITY
          // ------------------------------------------------------

          _buildSectionTitle(
            icon: Icons.lock_rounded,
            title: 'Account Security',
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: passwordController,
                  label: 'Password',
                  hint: 'Create password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscurePassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: textSecondary,
                    ),
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
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildTextField(
                  controller: confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscureConfirmPassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword =
                        !obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: textSecondary,
                    ),
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
            ],
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------------
          // TERMS
          // ------------------------------------------------------

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: agreeToTerms,
                  activeColor: primaryColor,
                  onChanged: (value) {
                    setState(() {
                      agreeToTerms = value ?? false;
                    });
                  },
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    children: [
                      const Text(
                        'I agree to the ',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(
                        ' and ',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ------------------------------------------------------
          // CREATE ACCOUNT BUTTON
          // ------------------------------------------------------

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
              isLoading ? null : createSponsorAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor:
                primaryColor.withOpacity(0.65),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
                  : const Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 19,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Create Sponsor Account',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: primaryColor,
          ),
        ),

        const SizedBox(width: 10),

        Text(
          title,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Divider(
            color: borderColor,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
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
      style: const TextStyle(
        color: textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 12,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
        ),
        prefixIcon: Icon(
          icon,
          size: 19,
          color: textSecondary,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATE DROPDOWN
  // ============================================================

  Widget _buildStateDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedState,
      decoration: InputDecoration(
        labelText: 'State',
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          Icons.map_outlined,
          size: 19,
          color: textSecondary,
        ),
        filled: true,
        fillColor: fieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 1.4,
          ),
        ),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: textSecondary,
      ),
      items: states.map(
            (state) {
          return DropdownMenuItem<String>(
            value: state,
            child: Text(
              state,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
              ),
            ),
          );
        },
      ).toList(),
      onChanged: (value) {
        setState(() {
          selectedState = value;
        });
      },
    );
  }

  // ============================================================
  // FILE PICKER
  // ============================================================

  Widget _buildFilePicker() {
    final bool hasFile =
        registrationCertificate != null;

    return InkWell(
      onTap: pickRegistrationCertificate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: fieldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile
                ? primaryColor.withOpacity(0.45)
                : borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                hasFile
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: hasFile
                    ? Colors.green
                    : primaryColor,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile
                        ? registrationCertificate!.name
                        : 'Upload Registration Certificate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasFile
                          ? textPrimary
                          : textSecondary,
                      fontSize: 12.5,
                      fontWeight: hasFile
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    hasFile
                        ? 'Certificate selected successfully'
                        : 'PDF, JPG or PNG',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.cloud_upload_outlined,
              color: primaryColor,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}