import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Generic read-only detail screen used by the Reports tabs to show
/// the full record for a student, sponsor, or scholarship.
class ReportDetailScreen extends StatelessWidget {
  final String headerTitle;
  final String headerSubtitle;
  final IconData icon;
  final Color color;
  final Map<String, dynamic> data;

  const ReportDetailScreen({
    super.key,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.icon,
    required this.color,
    required this.data,
  });

  // Converts a Firestore field key like "phoneNumber" into
  // a readable label like "Phone Number".
  String _labelFor(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
    );
    final withUnderscores = spaced.replaceAll('_', ' ');
    return withUnderscores
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ======================================================
              // HEADER
              // ======================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(.82),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "Details",
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                headerTitle,
                                style: AppTextStyles.title.copyWith(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                headerSubtitle,
                                style: AppTextStyles.subtitle.copyWith(
                                  color: Colors.white.withOpacity(.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ======================================================
              // FIELDS
              // ======================================================

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "All Information",
                      style: AppTextStyles.title.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 12),

                    if (entries.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            "No additional details available",
                            style: AppTextStyles.subtitle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: List.generate(entries.length, (i) {
                            final entry = entries[i];
                            final isLast = i == entries.length - 1;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                  bottom: BorderSide(
                                    color: AppColors.textSecondary
                                        .withOpacity(.08),
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 130,
                                    child: Text(
                                      _labelFor(entry.key),
                                      style:
                                      AppTextStyles.subtitle.copyWith(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.value?.toString().isNotEmpty ==
                                          true
                                          ? entry.value.toString()
                                          : "—",
                                      style:
                                      AppTextStyles.subtitle.copyWith(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}