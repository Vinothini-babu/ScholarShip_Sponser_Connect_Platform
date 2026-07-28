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
  final Color accent;

  const _RoleOption({
    required this.role,
    required this.icon,
    required this.label,
    required this.description,
    required this.accent,
  });
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;

  final List<_RoleOption> _options = [
    _RoleOption(
      role: UserRole.student,
      icon: Icons.school_rounded,
      label: 'Student',
      description: 'Find and apply for scholarships',
      accent: AppColors.primary,
    ),
    _RoleOption(
      role: UserRole.sponsor,
      icon: Icons.volunteer_activism_rounded,
      label: 'Sponsor',
      description: 'Fund students and track impact',
      accent: AppColors.secondary,
    ),
    _RoleOption(
      role: UserRole.admin,
      icon: Icons.admin_panel_settings_rounded,
      label: 'Admin',
      description: 'Manage users and verify applications',
      accent: AppColors.success,
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEAE1),
      body: Column(
        children: [
          // Navy gradient header — matches splash screen's identity
          Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 26,
                  24,
                  34,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.88)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const AppLogo(size: 54),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose Your Role',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select how you want to continue',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Soft decorative circle — same treatment as splash screen
              Positioned(
                top: -size.width * 0.18,
                right: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.55,
                  height: size.width * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary.withOpacity(0.12),
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // Top row — Student & Sponsor, centered content
                  Row(
                    children: [
                      Expanded(child: _RoleCard(option: _options[0], isSelected: _options[0].role == _selectedRole, onTap: () => setState(() => _selectedRole = _options[0].role))),
                      const SizedBox(width: 16),
                      Expanded(child: _RoleCard(option: _options[1], isSelected: _options[1].role == _selectedRole, onTap: () => setState(() => _selectedRole = _options[1].role))),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Bottom — Admin card, centered and narrower
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.55,
                      child: _RoleCard(option: _options[2], isSelected: _options[2].role == _selectedRole, onTap: () => setState(() => _selectedRole = _options[2].role)),
                    ),
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _selectedRole == null ? null : _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.25),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Role card — icon, label, description all centered vertically inside
/// a fixed-height rectangle, with press-scale + ripple feedback.
class _RoleCard extends StatefulWidget {
  final _RoleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  double _scale = 1.0;

  void _setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => _setScale(0.97),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: option.accent.withOpacity(0.15),
            highlightColor: option.accent.withOpacity(0.08),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 172,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? option.accent : AppColors.textSecondary.withOpacity(0.12),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? option.accent.withOpacity(0.28)
                        : Colors.black.withOpacity(0.14),
                    blurRadius: isSelected ? 20 : 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: option.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(option.icon, color: option.accent, size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        option.label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.description,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: isSelected
                          ? option.accent
                          : AppColors.textSecondary.withOpacity(0.3),
                      size: 20,
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
