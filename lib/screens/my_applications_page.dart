// pubspec: flutter pub add cloud_firestore firebase_auth intl
//
// Firestore "applications" doc fields used (rename below if yours differ):
//   studentId      (String)    -> FirebaseAuth uid
//   scholarshipTitle (String)
//   appliedAt      (Timestamp)
//   amount         (num)
//   college        (String)
//   status         (String)    -> 'pending' | 'approved' | 'rejected'
//   currentStep    (int)       -> 1 = Verified in progress, 2 = Decision in progress, 3 = all done
//   visitVenue     (String)    -> set when sponsor sends the visit message
//   visitDate      (Timestamp)
//   visitTime      (String)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _navy = Color(0xFF1E2A4A);
const _gold = Color(0xFFD4A22F);
const _green = Color(0xFF6B9A6F);
const _bg = Color(0xFFF7F5F0);

class MyApplicationsPage extends StatefulWidget {
  /// Called when "View Details" is tapped. Hook up your existing details page here.
  final void Function(String applicationId, Map<String, dynamic> data)? onViewDetails;

  const MyApplicationsPage({super.key, this.onViewDetails});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  String _filter = 'all'; // all | pending | approved | rejected

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('applications')
            .where('studentId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // newest first (sorted here so no Firestore index is needed)
          final all = snap.data!.docs.toList()
            ..sort((a, b) {
              final ta = (a['appliedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final tb = (b['appliedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return tb.compareTo(ta);
            });

          int count(String s) =>
              all.where((d) => (d['status'] ?? 'pending') == s).length;

          final shown = _filter == 'all'
              ? all
              : all.where((d) => (d['status'] ?? 'pending') == _filter).toList();

          return Column(
            children: [
              _Header(
                filter: _filter,
                all: all.length,
                pending: count('pending'),
                approved: count('approved'),
                rejected: count('rejected'),
                onFilter: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('No applications'))
                    : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final doc = shown[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return _ApplicationCard(
                          data: data,
                          onViewDetails: () =>
                              widget.onViewDetails?.call(doc.id, data),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------
// Header with filter tabs
// ---------------------------------------------------------------
class _Header extends StatelessWidget {
  final String filter;
  final int all, pending, approved, rejected;
  final ValueChanged<String> onFilter;

  const _Header({
    required this.filter,
    required this.all,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1E2A4A), Color(0xFF3B4A68)]),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text('My Applications',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text('Track your scholarship journey',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _tab('all', Icons.dashboard, all, 'All'),
                  _tab('pending', Icons.hourglass_bottom, pending, 'Pending'),
                  _tab('approved', Icons.check_circle, approved, 'Approved'),
                  _tab('rejected', Icons.cancel, rejected, 'Rejected'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String key, IconData icon, int n, String label) {
    final sel = filter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => onFilter(key),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? _gold : Colors.white24, width: sel ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: sel ? _navy : Colors.white70),
              const SizedBox(height: 6),
              Text('$n',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: sel ? _navy : Colors.white)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: sel ? _navy : Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// One application card
// ---------------------------------------------------------------
class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onViewDetails;

  const _ApplicationCard({required this.data, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final applied = (data['appliedAt'] as Timestamp?)?.toDate();
    final status = (data['status'] ?? 'pending') as String;
    final step = (data['currentStep'] ?? 1) as int;
    final amount = data['amount'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: const Border(left: BorderSide(color: _gold, width: 5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: _navy, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.school, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['scholarshipTitle'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        applied == null
                            ? ''
                            : 'Applied ${DateFormat('dd MMM yyyy').format(applied)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ]),
                  ],
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),

          // amount row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF6EA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEFE0B8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                  const BoxDecoration(color: _gold, shape: BoxShape.circle),
                  child: const Icon(Icons.account_balance_wallet,
                      size: 18, color: _navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Scholarship amount',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(
                          amount == null
                              ? '-'
                              : '\u20B9${NumberFormat('#,##,###', 'en_IN').format(amount)}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _navy)),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.account_balance, size: 13, color: _navy),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(data['college'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: _navy)),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // visit tracking banner (only shows when sponsor sent a visit message)
          _VisitBanner(app: data),

          // progress tracker
          _ProgressTracker(step: step),
          const SizedBox(height: 14),

          // view details
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onViewDetails,
              icon: const Icon(Icons.visibility, size: 18),
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View Details'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16, color: _gold),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Visit banner: "Trust Office, Gobichettipalayam - 30 Nov 2026, 10:00 AM"
// ---------------------------------------------------------------
class _VisitBanner extends StatelessWidget {
  final Map<String, dynamic> app;
  const _VisitBanner({required this.app});

  @override
  Widget build(BuildContext context) {
    final ts = app['visitDate'] as Timestamp?;
    if (ts == null) return const SizedBox.shrink();

    final date = DateFormat('dd MMM yyyy').format(ts.toDate());

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: _gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Document Verification Visit',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${app['visitVenue'] ?? ''}\n$date, ${app['visitTime'] ?? ''}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Applied -> Verified -> Decision tracker
// ---------------------------------------------------------------
class _ProgressTracker extends StatelessWidget {
  final int step; // 1 = Verified in progress, 2 = Decision in progress, 3 = done
  const _ProgressTracker({required this.step});

  @override
  Widget build(BuildContext context) {
    // index 0 Applied (always done), 1 Verified, 2 Decision
    Widget node(int i, IconData activeIcon, String label) {
      final done = i < step || (i == 0);
      final active = i == step;
      Color bg = Colors.grey.shade300;
      Widget icon = Icon(activeIcon, size: 16, color: Colors.grey);
      if (done) {
        bg = _green;
        icon = const Icon(Icons.check, size: 16, color: Colors.white);
      } else if (active) {
        bg = _gold;
        icon = Icon(activeIcon, size: 16, color: _navy);
      }
      return Column(
        children: [
          Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Center(child: icon)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: (done || active) ? _navy : Colors.grey)),
        ],
      );
    }

    Widget line(bool filled) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Container(
            height: 3, color: filled ? _green : Colors.grey.shade300),
      ),
    );

    return Row(
      children: [
        node(0, Icons.edit_document, 'Applied'),
        line(step > 1),
        node(1, Icons.fact_check, 'Verified'),
        line(step > 2),
        node(2, Icons.gavel, 'Decision'),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c = _gold;
    String t = 'Pending';
    if (status == 'approved') {
      c = _green;
      t = 'Approved';
    } else if (status == 'rejected') {
      c = Colors.red;
      t = 'Rejected';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: c),
        const SizedBox(width: 5),
        Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
      ]),
    );
  }
}