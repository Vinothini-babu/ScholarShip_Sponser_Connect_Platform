// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

const Color _kNavy = Color(0xFF1E3358);
const Color _kAmber = Color(0xFFF5A623);

const List<String> _monthNames = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

/// Indian digit grouping: 120000 -> 1,20,000
String _inr(num value) {
  final n = value.round();
  final s = n.abs().toString();
  final sign = n < 0 ? "-" : "";
  if (s.length <= 3) return "$sign$s";
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return "$sign${parts.join(',')},$last3";
}

String _first(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
  }
  return "";
}

// ============================================================
// DATA
// ============================================================

class SponsorFund {
  final String name;
  final double funds;
  final int scholarships;

  const SponsorFund({
    required this.name,
    required this.funds,
    required this.scholarships,
  });
}

class _BarItem {
  final String label;
  final double value;
  final String valueText;

  const _BarItem(this.label, this.value, this.valueText);
}

class ReportAnalyticsData {
  /// last 6 months, oldest first (label, applications)
  final List<MapEntry<String, int>> monthly;

  /// top 5 scholarships by applications received
  final List<MapEntry<String, int>> topScholarships;

  /// top 5 sponsors by scholarship funds
  final List<SponsorFund> sponsorFunds;

  final int students;
  final int sponsors;
  final int scholarships;
  final int applications;
  final int approved;
  final int pending;
  final int rejected;
  final double totalFunds;

  const ReportAnalyticsData._({
    required this.monthly,
    required this.topScholarships,
    required this.sponsorFunds,
    required this.students,
    required this.sponsors,
    required this.scholarships,
    required this.applications,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.totalFunds,
  });

  factory ReportAnalyticsData.build({
    required List<Map<String, dynamic>> applications,
    required List<SponsorFund> sponsorFunds,
    required int students,
    required int sponsors,
    required int scholarships,
    required int approved,
    required int pending,
    required int rejected,
    required double totalFunds,
  }) {
    // ---- month-wise applications (last 6 months)
    final now = DateTime.now();
    final months = List<DateTime>.generate(
      6,
          (i) => DateTime(now.year, now.month - (5 - i), 1),
    );
    final counts = List<int>.filled(6, 0);

    // ---- scholarship -> number of applications
    final perScholarship = <String, int>{};

    for (final a in applications) {
      final t = a["appliedAt"] ?? a["createdAt"];
      if (t is Timestamp) {
        final d = t.toDate();
        for (int i = 0; i < 6; i++) {
          if (months[i].year == d.year && months[i].month == d.month) {
            counts[i]++;
            break;
          }
        }
      }

      var name = _first(a, ["scholarshipTitle", "scholarshipName", "title"]);
      if (name.isEmpty) name = _first(a, ["scholarshipId", "scholarship_id"]);
      if (name.isNotEmpty) {
        perScholarship[name] = (perScholarship[name] ?? 0) + 1;
      }
    }

    final monthly = <MapEntry<String, int>>[
      for (int i = 0; i < 6; i++)
        MapEntry(_monthNames[months[i].month - 1], counts[i]),
    ];

    final top = perScholarship.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final funds = sponsorFunds.where((s) => s.funds > 0).toList()
      ..sort((a, b) => b.funds.compareTo(a.funds));

    return ReportAnalyticsData._(
      monthly: monthly,
      topScholarships: top.take(5).toList(),
      sponsorFunds: funds.take(5).toList(),
      students: students,
      sponsors: sponsors,
      scholarships: scholarships,
      applications: applications.length,
      approved: approved,
      pending: pending,
      rejected: rejected,
      totalFunds: totalFunds,
    );
  }

  double get approvalRate =>
      applications == 0 ? 0 : approved / applications * 100;
}

// ============================================================
// ON-SCREEN CHARTS
// ============================================================

class ReportAnalyticsSection extends StatelessWidget {
  final ReportAnalyticsData data;

  const ReportAnalyticsSection({super.key, required this.data});

  Widget _panel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: AppTextStyles.subtitle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthlyPanel = _panel(
      title: "Applications by Month",
      subtitle: "Last 6 months",
      icon: Icons.bar_chart_rounded,
      color: _kNavy,
      child: _MonthlyBars(data: data.monthly),
    );

    final topPanel = _panel(
      title: "Top Scholarships",
      subtitle: "Most applied scholarships",
      icon: Icons.emoji_events_rounded,
      color: _kAmber,
      child: data.topScholarships.isEmpty
          ? _empty("No applications yet")
          : _HBars(
        color: _kAmber,
        items: [
          for (final e in data.topScholarships)
            _BarItem(e.key, e.value.toDouble(), "${e.value}"),
        ],
      ),
    );

    final fundsPanel = _panel(
      title: "Sponsor-wise Funds",
      subtitle: "Total scholarship amount offered by each sponsor",
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.success,
      child: data.sponsorFunds.isEmpty
          ? _empty("No sponsor funds yet")
          : _HBars(
        color: AppColors.success,
        items: [
          for (final s in data.sponsorFunds)
            _BarItem(s.name, s.funds, "₹${_inr(s.funds)}"),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        if (wide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: monthlyPanel),
                  const SizedBox(width: 14),
                  Expanded(child: topPanel),
                ],
              ),
              const SizedBox(height: 14),
              fundsPanel,
            ],
          );
        }

        return Column(
          children: [
            monthlyPanel,
            const SizedBox(height: 14),
            topPanel,
            const SizedBox(height: 14),
            fundsPanel,
          ],
        );
      },
    );
  }
}

/// Vertical bars, one per month.
class _MonthlyBars extends StatelessWidget {
  final List<MapEntry<String, int>> data;

  const _MonthlyBars({required this.data});

  @override
  Widget build(BuildContext context) {
    var maxV = 0;
    for (final e in data) {
      if (e.value > maxV) maxV = e.value;
    }

    if (maxV == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            "No applications in the last 6 months",
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in data)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "${e.value}",
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: e.value / maxV),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) {
                      return Container(
                        width: 28,
                        height: e.value == 0 ? 3 : 8 + 112 * v,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _kNavy,
                              _kNavy.withOpacity(.65),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.key,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal labelled bars.
class _HBars extends StatelessWidget {
  final List<_BarItem> items;
  final Color color;

  const _HBars({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    var maxV = 0.0;
    for (final it in items) {
      if (it.value > maxV) maxV = it.value;
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      items[i].valueText,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, c) {
                    final fraction = maxV == 0 ? 0.0 : items[i].value / maxV;
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: fraction),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) {
                        return Stack(
                          children: [
                            Container(
                              width: c.maxWidth,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color.withOpacity(.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Container(
                              width: c.maxWidth * v,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ============================================================
// PDF EXPORT
// ============================================================

/// Builds the report PDF and opens the system print / save-as-PDF preview.
Future<void> exportReportPdf(ReportAnalyticsData d) async {
  final doc = pw.Document();
  final navy = PdfColor.fromInt(0xFF1E3358);
  final amber = PdfColor.fromInt(0xFFF5A623);
  final green = PdfColor.fromInt(0xFF2E9E5B);

  final now = DateTime.now();
  final dateText =
      "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
  final fileDate =
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

  String pct(int v) =>
      d.applications == 0 ? "0%" : "${(v / d.applications * 100).round()}%";

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: navy,
      ),
    ),
  );

  pw.Widget cell(String text, {bool head = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: head ? PdfColors.white : PdfColors.black,
      ),
    ),
  );

  pw.Widget table(List<String> headers, List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: navy),
          children: [for (final h in headers) cell(h, head: true)],
        ),
        for (final r in rows)
          pw.TableRow(children: [for (final c in r) cell(c)]),
      ],
    );
  }

  pw.Widget bars(List<_BarItem> items, PdfColor color) {
    if (items.isEmpty) {
      return pw.Text(
        "No data yet",
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      );
    }
    var maxV = 0.0;
    for (final it in items) {
      if (it.value > maxV) maxV = it.value;
    }
    return pw.Column(
      children: [
        for (final it in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 150,
                  child: pw.Text(
                    it.label,
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Container(
                  width: maxV == 0 ? 0.0 : 220.0 * it.value / maxV,
                  height: 9,
                  color: color,
                ),
                pw.SizedBox(width: 6),
                pw.Text(it.valueText, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }

  // NOTE: the default PDF font has no rupee sign, so "Rs." is used here.
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text(
          "Scholarship Sponsor Connect",
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: navy,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          "Admin Report  |  Generated on $dateText",
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.Divider(color: amber, thickness: 1.5),

        heading("Summary"),
        table(
          ["Metric", "Value"],
          [
            ["Students", "${d.students}"],
            ["Sponsors", "${d.sponsors}"],
            ["Scholarships", "${d.scholarships}"],
            ["Applications", "${d.applications}"],
            ["Approval rate", "${d.approvalRate.round()}%"],
            ["Total scholarship funds", "Rs. ${_inr(d.totalFunds)}"],
          ],
        ),

        heading("Application Status"),
        table(
          ["Status", "Applications", "Share"],
          [
            ["Approved", "${d.approved}", pct(d.approved)],
            ["Pending", "${d.pending}", pct(d.pending)],
            ["Rejected", "${d.rejected}", pct(d.rejected)],
          ],
        ),

        heading("Applications by Month (last 6 months)"),
        bars(
          [
            for (final e in d.monthly)
              _BarItem(e.key, e.value.toDouble(), "${e.value}"),
          ],
          navy,
        ),

        heading("Top Scholarships (most applied)"),
        bars(
          [
            for (final e in d.topScholarships)
              _BarItem(e.key, e.value.toDouble(), "${e.value}"),
          ],
          amber,
        ),

        heading("Sponsor-wise Funds"),
        bars(
          [
            for (final s in d.sponsorFunds)
              _BarItem(s.name, s.funds, "Rs. ${_inr(s.funds)}"),
          ],
          green,
        ),
        if (d.sponsorFunds.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          table(
            ["Sponsor", "Scholarships", "Total funds"],
            [
              for (final s in d.sponsorFunds)
                [s.name, "${s.scholarships}", "Rs. ${_inr(s.funds)}"],
            ],
          ),
        ],
      ],
    ),
  );

  await Printing.layoutPdf(
    name: "scholarship_report_$fileDate.pdf",
    onLayout: (format) async => doc.save(),
  );
}