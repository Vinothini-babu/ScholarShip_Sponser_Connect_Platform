import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import '../student/student_dashboard.dart';
import 'signup_screen.dart';
import '../sponser/sponser_dashboard.dart';
import '../admin/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AuthService _authService = AuthService();

  bool obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Successful")),
      );

      String role = await _authService.getUserRole();

      if (!mounted) return;

      if (role == "student") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentDashboard()),
        );
      } else if (role == "sponsor") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SponsorDashboard()),
        );
      } else if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid user role")),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login Failed")),
      );
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: const AppLogo(size: 200)),

                const SizedBox(height: 28),

                Text(
                  "Welcome Back",
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 28,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Sign in to continue your journey",
                  style: AppTextStyles.subtitle,
                ),

                const SizedBox(height: 32),

                Text("Email", style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Enter your email";
                    }
                    return null;
                  },
                  decoration: _fieldDecoration(
                    hint: "Email Address",
                    icon: Icons.email_outlined,
                  ),
                ),

                const SizedBox(height: 18),

                Text("Password", style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter your password";
                    }
                    return null;
                  },
                  decoration: _fieldDecoration(
                    hint: "Password",
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      "Forgot Password?",
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                        : const Text("Sign In"),
                  ),
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: Divider(color: AppColors.textSecondary.withOpacity(0.2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "OR",
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: AppColors.textSecondary.withOpacity(0.2)),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        );
                      },
                      child: Text(
                        "Create Account",
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Center(
                  child: Text(
                    "Made with ❤️ by PKR Student",
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
