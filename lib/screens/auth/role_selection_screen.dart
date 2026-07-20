import 'package:flutter/material.dart';
import '../../widgets/role_card.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [

              const SizedBox(height: 40),

              // Logo
              const Icon(
                Icons.school_rounded,
                size: 100,
                color: Color(0xFF2563EB),
              ),

              const SizedBox(height:02),

              const Text(
                "Scholarship Sponsor Connect Platform",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Connecting Dreams with Opportunities",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 35),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Choose Your Role",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              RoleCard(
                icon: Icons.school_rounded,
                title: "Student",
                subtitle: "Find & Apply for Scholarships",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),

              RoleCard(
                icon: Icons.volunteer_activism_rounded,
                title: "Sponsor",
                subtitle: "Support Students Through Scholarships",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),

              RoleCard(
                icon: Icons.admin_panel_settings_rounded,
                title: "Admin",
                subtitle: "Manage the Platform",
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

              const Text(
                "Version 1.0",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}