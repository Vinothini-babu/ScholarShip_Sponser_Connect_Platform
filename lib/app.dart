import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

class ScholarshipSponsorConnectApp extends StatelessWidget {
  const ScholarshipSponsorConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scholarship Sponsor Connect',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}