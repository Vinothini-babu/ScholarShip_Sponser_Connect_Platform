import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/app_logo.dart';
import '../auth/role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    // Single, simple fade-in. No moving parts beyond this.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 96),
                const SizedBox(height: 24),

                Text(
                  'Scholarship Sponsor',
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Connect Platform',
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Connecting Dreams with Opportunities',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle,
                ),

                const SizedBox(height: 48),

                // Thin static line — a quiet nod to "connection" without motion
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(2),
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
