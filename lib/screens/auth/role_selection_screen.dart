import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/premium_role_card.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: Stack(
        children: [

          // Background Circle
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const SizedBox(height: 15),

                  const Center(
                    child: AppLogo(size: 200),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "Welcome 👋",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "Choose your role to continue",
                    style: AppTextStyles.subtitle,
                  ),

                  const SizedBox(height: 35),

                  PremiumRoleCard(
                    icon: Icons.school_rounded,
                    iconColor: Colors.blue,
                    title: "Student",
                    subtitle: "Find & Apply Scholarships",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  PremiumRoleCard(
                    icon: Icons.favorite,
                    iconColor: Colors.green,
                    title: "Sponsor",
                    subtitle: "Support Students",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  PremiumRoleCard(
                    icon: Icons.admin_panel_settings,
                    iconColor: Colors.orange,
                    title: "Admin",
                    subtitle: "Manage Platform",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                  ),

                  const Spacer(),

                  const Center(
                    child: Text(
                      "Scholarship Sponsor Connect",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Center(
                    child: Text(
                      "Version 2.0",
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}