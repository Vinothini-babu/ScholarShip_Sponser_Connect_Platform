import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/app_logo.dart';
import '../auth/login_screen.dart';

enum UserRole { student, sponsor, admin }

class _RoleOption {
  final UserRole role;
  final IconData icon;
  final String label;
  final String description;

  const _RoleOption({
    required this.role,
    required this.icon,
    required this.label,
    required this.description,
  });
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;

  final List<_RoleOption> _options = const [
    _RoleOption(
      role: UserRole.student,
      icon: Icons.school_rounded,
      label: 'Student',
      description: 'Find and apply for scholarships',
    ),
    _RoleOption(
      role: UserRole.sponsor,
      icon: Icons.volunteer_activism_rounded,
      label: 'Sponsor',
      description: 'Fund students and track impact',
    ),
    _RoleOption(
      role: UserRole.admin,
      icon: Icons.admin_panel_settings_rounded,
      label: 'Admin',
      description: 'Manage users and verify applications',
    ),
  ];

  void _continue() {
    if (_selectedRole == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 28),

              const AppLogo(size: 300),

              const SizedBox(height: 2),

              Text(
                'Choose Your Role?',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading.copyWith(
                  fontSize: 26,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your role to continue',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle,
              ),

              const SizedBox(height: 32),

              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    final isSelected = option.role == _selectedRole;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedRole = option.role),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.secondary
                                : AppColors.textSecondary.withOpacity(0.15),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                              : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.secondary
                                    : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                option.icon,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.secondary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: AppTextStyles.subtitle.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    option.description,
                                    style: AppTextStyles.subtitle.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? AppColors.secondary
                                  : AppColors.textSecondary.withOpacity(0.3),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedRole == null ? null : _continue,
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}