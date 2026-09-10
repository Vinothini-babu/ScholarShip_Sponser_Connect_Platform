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
  static const _splashDuration = Duration(milliseconds: 6500);

  late final AnimationController _controller;

  // Logo: scale + fade in first
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Title: fades + slides up slightly after the logo
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  // Subtitle: fades + slides up after the title
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;

  // Decorative circles: gentle scale-in for depth
  late final Animation<double> _circleScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _circleScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
      ),
    );

    _subtitleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
      ),
    );

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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Solid navy gradient background — stays dark throughout so
          // white text remains legible everywhere on screen
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.88),
                ],
              ),
            ),
          ),

          // Soft decorative circle — top right, gold tint
          Positioned(
            top: -size.width * 0.22,
            right: -size.width * 0.28,
            child: ScaleTransition(
              scale: _circleScale,
              child: Container(
                width: size.width * 0.75,
                height: size.width * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(0.12),
                ),
              ),
            ),
          ),

          // Soft decorative circle — bottom left, subtle white
          Positioned(
            bottom: -size.width * 0.2,
            left: -size.width * 0.22,
            child: ScaleTransition(
              scale: _circleScale,
              child: Container(
                width: size.width * 0.6,
                height: size.width * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo sits on a soft white card so it stays legible
                    // over both the navy top and paper bottom of the gradient
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const AppLogo(size: 88),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Text(
                          "Scholarship Sponsor\nConnect Platform",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    FadeTransition(
                      opacity: _subtitleFade,
                      child: SlideTransition(
                        position: _subtitleSlide,
                        child: Text(
                          "\"Where opportunity meets ambition —\nconnecting students and sponsors\nto build brighter futures.\"",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 52),

                    FadeTransition(
                      opacity: _subtitleFade,
                      child: const _LoadingIndicator(),
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