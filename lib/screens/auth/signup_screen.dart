import 'package:flutter/material.dart';


import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController collegeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();


  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Join Scholarship Sponsor Connect",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 35),

              // Signup fields next step
              CustomTextField(
                controller: nameController,
                hintText: "Full Name",
                prefixIcon: Icons.person_outline,
              ),

              const SizedBox(height: 18),

              CustomTextField(
                controller: emailController,
                hintText: "Email Address",
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 18),

              CustomTextField(
                controller: mobileController,
                hintText: "Mobile Number",
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 18),

              CustomTextField(
                controller: collegeController,
                hintText: "College Name",
                prefixIcon: Icons.school_outlined,
              ),

              const SizedBox(height: 18),

              CustomTextField(
                controller: passwordController,
                hintText: "Password",
                prefixIcon: Icons.lock_outline,
                obscureText: obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),

              const SizedBox(height: 18),

              CustomTextField(
                controller: confirmPasswordController,
                hintText: "Confirm Password",
                prefixIcon: Icons.lock_outline,
                obscureText: obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                ),
              ),

              const SizedBox(height: 25),

              CustomButton(
                text: "Create Account",
                onPressed: () {},
              ),

            ],
          ),
        ),
      ),
    );
  }
}