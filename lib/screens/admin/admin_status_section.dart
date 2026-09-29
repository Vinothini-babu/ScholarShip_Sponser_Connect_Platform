// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// TODO: unga folder structure ku aetha path maathunga
import 'view_applications_screen.dart';

const Color _navy = Color(0xFF1E3358);

String _normalizeStatus(dynamic raw) {
  final s = raw?.toString().trim().toLowerCase() ?? "pending";
  if (s == "approved") return "Approved";
  if (s == "rejected" || s == "reject") return "Rejected";
  return "Pending";
}

// ============================================================
// APPLICATION STATUS SECTION  (dashboard la idha use pannunga)
// ============================================================

class AdminStatusSection extends StatefulWidget {
  const AdminStatusSection({super.key});

  @override
  State<AdminStatusSection> createState() => _AdminStatusSectionState();
}

class _AdminStatusSectionState extends State<AdminStatusSection> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance.collection("applications").snapshots();
  }

  void _open(String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewApplicationsScreen(initialFilter: filter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        int pending = 0, approved = 0, rejected = 0;

        for (final d in snap.data?.docs ?? const []) {
          switch (_normalizeStatus(d.data()["status"])) {
            case "Approved":
              approved++;
              break;
            case "Rejected":
              rejected++;
              break;
            default:
              pending++;
          }
        }

        final total = pending + approved + rejected;
        double pct(int c) => total == 0 ? 0 : c / total;

        final cards = [
          _StatusCard(
            label: "Pending",
            count: pending,
            percent: pct(pending),
            color: Colors.orange,
            icon: Icons.hourglass_top_rounded,
            onTap: () => _open("Pending"),
          ),
          _StatusCard(
            label: "Approved",
            count: approved,
            percent: pct(approved),
            color: Colors.green,
            icon: Icons.check_circle_rounded,
            onTap: () => _open("Approved"),
          ),
          _StatusCard(
            label: "Rejected",
            count: rejected,
            percent: pct(rejected),
            color: Colors.red,
            icon: Icons.cancel_rounded,
            onTap: () => _open("Rejected"),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Application Status",
                  style: TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                // narrow screen (mobile) -> stack, wide (desktop) -> row
                if (c.maxWidth < 600) {
                  return Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card,
                        ),
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 14),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// SINGLE TAPPABLE CARD
// ============================================================

class _StatusCard extends StatelessWidget {
  final String label;
  final int count;
  final double percent; // 0..1
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusCard({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap, // <-- click panna filter oda View Applications open aagum
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: _navy.withOpacity(0.75),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "$count",
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 5,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${(percent * 100).round()}% of all applications",
                style: TextStyle(
                  color: _navy.withOpacity(0.6),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}