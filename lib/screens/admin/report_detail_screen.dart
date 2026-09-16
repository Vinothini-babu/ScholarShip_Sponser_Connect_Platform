import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Generic read-only detail screen used by the Reports tabs to show
/// the full record for a student, sponsor, scholarship, or application.
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

  // Field keys that get pulled out and shown as highlighted chips
  // right under the header, instead of buried in the plain list.
  static const List<String> _highlightKeys = [
    "status",
    "amount",
    "percentage",
    "category",
  ];

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

  // Turns raw Firestore values (Timestamp, List, etc.) into readable text.
  String _formatValue(dynamic value) {
    if (value == null) return "—";

    if (value is Timestamp) {
      final d = value.toDate();
      const months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
      ];
      final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ampm = d.hour >= 12 ? "PM" : "AM";
      final minute = d.minute.toString().padLeft(2, '0');
      return "${d.day} ${months[d.month - 1]} ${d.year}, $hour12:$minute $ampm";
    }

    if (value is List) {
      return value.map((e) => e.toString()).join(", ");
    }

    final text = value.toString();
    return text.isNotEmpty ? text : "—";
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "active":
        return AppColors.success;
      case "rejected":
      case "inactive":
        return AppColors.error;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final highlightEntries = allEntries
        .where((e) => _highlightKeys.contains(e.key.toLowerCase()))
        .toList();

    final listEntries = allEntries
        .where((e) => !_highlightKeys.contains(e.key.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ==================================================
              // HEADER
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(.80)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
                      crossAxisAlignment: CrossAxisAlignment.center,
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

              const SizedBox(height: 20),

              // ==================================================
              // HIGHLIGHTED CHIPS (status / amount / etc.)
              // ==================================================

              if (highlightEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: highlightEntries.map((entry) {
                      final isStatus =
                          entry.key.toLowerCase() == "status";
                      final chipColor = isStatus
                          ? _statusColor(entry.value.toString())
                          : color;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              chipColor.withOpacity(.16),
                              chipColor.withOpacity(.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: chipColor.withOpacity(.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              _labelFor(entry.key),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: chipColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.key.toLowerCase() == "amount"
                                  ? "₹${_formatValue(entry.value)}"
                                  : _formatValue(entry.value),
                              style: AppTextStyles.title.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              // ==================================================
              // FIELDS
              // ==================================================

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "All Information",
                      style:
                      AppTextStyles.title.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 12),

                    if (listEntries.isEmpty)
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
                          children:
                          List.generate(listEntries.length, (i) {
                            final entry = listEntries[i];
                            final isLast =
                                i == listEntries.length - 1;
                            final isEven = i % 2 == 0;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isEven
                                    ? Colors.transparent
                                    : color.withOpacity(.03),
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
                                    width: 150,
                                    child: Text(
                                      _labelFor(entry.key),
                                      style: AppTextStyles.subtitle
                                          .copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color:
                                        AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _formatValue(entry.value),
                                      style: AppTextStyles.subtitle
                                          .copyWith(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
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