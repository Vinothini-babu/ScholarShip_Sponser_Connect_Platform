import 'package:cloud_firestore/cloud_firestore.dart';

/// Creates a bell notification for a student when a scholarship they have
/// NOT applied to closes within [_windowDays] days.
///
/// Runs on the client (no Cloud Functions needed on the Spark plan):
/// the first time the student opens the app each session it checks all
/// scholarships. Notification doc ids are fixed per student + scholarship,
/// so the same reminder is never created twice.
///   - "soon"  reminder: 2-3 days left
///   - "final" reminder: 1 day left / today
class DeadlineReminderService {
  static const int _windowDays = 3;
  static final Set<String> _doneThisSession = {};

  static Future<void> runFor(String uid) async {
    if (!_doneThisSession.add(uid)) return;

    try {
      final db = FirebaseFirestore.instance;

      // students only (this runs for every logged-in user)
      final userDoc = await db.collection('users').doc(uid).get();
      if ((userDoc.data()?['role'] ?? '').toString() != 'student') return;

      // scholarships already applied to
      final apps = await db
          .collection('applications')
          .where('studentId', isEqualTo: uid)
          .get();
      final applied = apps.docs
          .map((d) => d.data()['scholarshipId']?.toString())
          .whereType<String>()
          .toSet();

      final scholarships = await db.collection('scholarships').get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final s in scholarships.docs) {
        if (applied.contains(s.id)) continue;

        final data = s.data();
        final last = _parseDate(data['lastDate'] ?? data['deadline']);
        if (last == null) continue;

        final lastDay = DateTime(last.year, last.month, last.day);
        final daysLeft = lastDay.difference(today).inDays;
        if (daysLeft < 0 || daysLeft > _windowDays) continue;

        final bucket = daysLeft <= 1 ? 'final' : 'soon';
        final ref = db
            .collection('notifications')
            .doc('deadline_${uid}_${s.id}_$bucket');
        if ((await ref.get()).exists) continue;

        final title = (data['title'] ?? 'A scholarship').toString();
        final when = daysLeft == 0
            ? 'closes today'
            : daysLeft == 1
            ? 'closes tomorrow'
            : 'closes in $daysLeft days';
        final dateText =
            '${last.day.toString().padLeft(2, '0')}/${last.month.toString().padLeft(2, '0')}/${last.year}';

        await ref.set({
          'audience': 'student',
          'userId': uid,
          'studentId': uid,
          'type': 'deadline_reminder',
          'title': 'Deadline approaching ⏰',
          'body': '$title $when ($dateText). Apply before it closes.',
          'scholarshipId': s.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // reminders are best-effort; never break app start
    }
  }

  // Same formats the rest of the app uses for lastDate:
  // Timestamp, "dd/mm/yyyy" or "yyyy-mm-dd"
  static DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      final p = v.trim().split(RegExp(r'[/\-.]'));
      if (p.length == 3) {
        final a = int.tryParse(p[0]);
        final b = int.tryParse(p[1]);
        final c = int.tryParse(p[2]);
        if (a != null && b != null && c != null) {
          if (p[0].length == 4) return DateTime(a, b, c);
          return DateTime(c, b, a);
        }
      }
    }
    return null;
  }
}