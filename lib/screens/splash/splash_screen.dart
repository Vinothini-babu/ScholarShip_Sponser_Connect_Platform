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

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    Timer(
      const Duration(seconds: 4),
          () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RoleSelectionScreen(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        decoration: const BoxDecoration(

          gradient: LinearGradient(

            begin: Alignment.topLeft,
            end: Alignment.bottomRight,

            colors: [

              Color(0xFF2563EB),

              Color(0xFF3B82F6),

              Color(0xFF60A5FA),

            ],

          ),

        ),

        child: SafeArea(

          child: Center(

            child: FadeTransition(

              opacity: _controller,

              child: Column(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  const AppLogo(size: 140),

                  const SizedBox(height: 35),

                  const Text(

                    "Scholarship Sponsor",

                    style: AppTextStyles.heading,

                  ),

                  const Text(

                    "Connect Platform",

                    style: AppTextStyles.heading,

                  ),

                  const SizedBox(height: 15),

                  const Text(

                    "Connecting Dreams with Opportunities",

                    textAlign: TextAlign.center,

                    style: TextStyle(

                      color: Colors.white70,

                      fontSize: 16,

                    ),

                  ),

                  const SizedBox(height: 50),

                  const CircularProgressIndicator(

                    color: Colors.white,

                  ),

                  const SizedBox(height: 25),

                  const Text(

                    "Loading...",

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 16,

                    ),

                  ),

                  const SizedBox(height: 80),

                  const Text(

                    "Version 2.0",

                    style: TextStyle(

                      color: Colors.white70,

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

}