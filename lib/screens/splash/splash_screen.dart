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
  static const _splashDuration = Duration(milliseconds: 5000);

  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Timer(_splashDuration, () {
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 108),

                  const SizedBox(height: 26),

                  Text(
                    "Scholarship Sponsor\nConnect Platform",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "\"Where opportunity meets ambition —\nconnecting students and sponsors\nto build brighter futures.\"",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 52),

                  const _LoadingIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Loading" text with a soft pulsing opacity + three sequential dots.
/// One continuous animation only — kept minimal on purpose.
class _LoadingIndicator extends StatefulWidget {
  const _LoadingIndicator();

  @override
  State<_LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<_LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dotCount = (_controller.value * 3).floor() + 1; // 1,2,3 looping
        final dots = "." * dotCount;

        return Text(
          "Loading$dots",
          style: AppTextStyles.subtitle.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        );
      },
    );
  }
}
