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
  late final Animation<double> _fade; // quick entrance fade

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _splashDuration,
    )..forward();

    // Content fades in fast (first 600ms), then holds
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.09, curve: Curves.easeOut),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size:350),
                const SizedBox(height: 30),

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

                // Signature element: three dots popping up in sequence —
                // reads as "student • platform • sponsor" connecting
                const _PopDotsLoader(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots that pop up one after another in a loop — reads as
/// "student • platform • sponsor" connecting. Replaces a generic
/// CircularProgressIndicator with something on-theme.
class _PopDotsLoader extends StatefulWidget {
  const _PopDotsLoader();

  @override
  State<_PopDotsLoader> createState() => _PopDotsLoaderState();
}

class _PopDotsLoaderState extends State<_PopDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _cycleDuration = Duration(milliseconds: 1100);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycleDuration)
      ..repeat();
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot's "pop" is offset by 0.15 of the cycle
            final t = ((_controller.value - (i * 0.18)) % 1.0);

            // Pop up then settle: scale 0 -> 1.3 -> 1.0, fade in
            double scale;
            double opacity;
            if (t < 0.35) {
              final localT = t / 0.35;
              scale = Curves.easeOutBack.transform(localT) * 1.0;
              opacity = localT.clamp(0.0, 1.0);
            } else {
              scale = 1.0;
              opacity = 1.0;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, (1 - scale) * 10),
                  child: Transform.scale(
                    scale: scale.clamp(0.0, 1.3),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
