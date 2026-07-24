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

  late final Animation<double> _logoScale;
  late final Animation<double> _threadProgress;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
    );

    _threadProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
    ));

    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
    );

    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 0.9, curve: Curves.easeOut),
    );

    _loaderFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 3400), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, animation, __) => const RoleSelectionScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
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
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Soft radial glow instead of a flat gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withOpacity(0.85),
                    AppColors.primary,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _logoScale,
                      child: const AppLogo(size: 120),
                    ),
                    const SizedBox(height: 28),

                    // Signature element: thread connecting two nodes
                    // (student <-> sponsor) drawing itself in
                    SizedBox(
                      width: 130,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _node(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: CustomPaint(
                                size: const Size(double.infinity, 3),
                                painter: _ThreadPainter(_threadProgress.value),
                              ),
                            ),
                          ),
                          _node(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Column(
                          children: [
                            Text(
                              'Scholarship Sponsor',
                              style: AppTextStyles.heading.copyWith(fontSize: 24),
                            ),
                            Text(
                              'Connect Platform',
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 24,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeTransition(
                      opacity: _taglineFade,
                      child: Text(
                        'Connecting Dreams with Opportunities',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.white.withOpacity(0.7),
                        ),
                      ),
                    ),

                    const SizedBox(height: 56),

                    FadeTransition(
                      opacity: _loaderFade,
                      child: const _PulsingDotsLoader(),
                    ),
                  ],
                );
              },
            ),
          ),

          // Version tag, bottom
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Version 2.0',
                style: TextStyle(
                  color: AppColors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _node() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ThreadPainter extends CustomPainter {
  final double progress;
  _ThreadPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final active = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), base);
    canvas.drawLine(Offset(0, y), Offset(size.width * progress, y), active);
  }

  @override
  bool shouldRepaint(covariant _ThreadPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Custom loader — three dots pulsing in sequence, replacing the
/// default CircularProgressIndicator for a less generic feel.
class _PulsingDotsLoader extends StatefulWidget {
  const _PulsingDotsLoader();

  @override
  State<_PulsingDotsLoader> createState() => _PulsingDotsLoaderState();
}

class _PulsingDotsLoaderState extends State<_PulsingDotsLoader>
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - (i * 0.2)) % 1.0;
            final scale = t < 0.5 ? 1.0 + (t * 0.8) : 1.4 - ((t - 0.5) * 0.8);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale.clamp(1.0, 1.4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
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
