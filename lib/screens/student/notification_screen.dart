import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/notification_service.dart';
import 'all_scholarships_screen.dart';
import 'my_applications_screen.dart';
import 'scholarship_applications_screen.dart';
import 'scholarship_info_screen.dart';
import '../../utils/eligibility_utils.dart';

// =========================================================
// BELL (use in the student dashboard header)
// =========================================================

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // quick ringing swing in the first third of every cycle, then rest
  double _swing(double t) {
    if (t > 0.35) return 0;
    final p = t / 0.35;
    return math.sin(p * math.pi * 4) * 0.42 * (1 - p);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: NotificationService().unreadCount(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        final active = count > 0;

        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (active)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale: 1 + 0.9 * t,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.secondary
                                  .withOpacity((1 - t) * 0.9),
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Material(
                  color: active
                      ? AppColors.secondary.withOpacity(0.38)
                      : Colors.white.withOpacity(0.16),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Transform.rotate(
                        angle: active ? _swing(t) : 0,
                        child: const Icon(Icons.notifications_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
                if (active)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        count > 99 ? "99+" : "$count",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// =========================================================
// INVITE DETAILS  (professional, real-time invitation view)
// Used by: notification list, popup banner, dashboard highlight card
// =========================================================

String _firstText(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return "";
  for (final k in keys) {
    final v = _val(m[k]);
    if (v.isNotEmpty) return v;
  }
  return "";
}

String _val(dynamic v) {
  if (v == null) return "";
  if (v is Timestamp) {
    final d = v.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }
  if (v is List) {
    return v
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .join(", ");
  }
  if (v is bool) return v ? "Yes" : "No";
  return v.toString().trim();
}

const List<String> _legacyDefaultDocs = [
  "Marksheet",
  "ID Proof",
  "Income Certificate",
  "College ID",
];

String _padDate(dynamic v) {
  if (v is Timestamp) {
    final d = v.toDate();
    return "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}/${d.year}";
  }
  return _val(v);
}

/// The existing documents + SOP apply form for one scholarship.
Widget _applicationForm(String id, Map<String, dynamic> d) {
  final docs = (d["requiredDocuments"] is List &&
      (d["requiredDocuments"] as List).isNotEmpty)
      ? (d["requiredDocuments"] as List).map((e) => e.toString()).toList()
      : _legacyDefaultDocs;
  final title = _val(d["title"]);
  return ScholarshipApplicationScreen(
    scholarshipId: id,
    title: title.isEmpty ? "Scholarship" : title,
    amount: _val(d["amount"]),
    lastDate: _padDate(d["lastDate"]),
    eligibility: _val(d["eligibility"]),
    requiredDocuments: docs,
  );
}

String _inviteStatus(Map<String, dynamic> m) =>
    (m["status"] ?? "invited").toString();

/// An invitation that still needs the student's attention
/// (not yet applied, not declined).
bool _isPendingInvite(Map<String, dynamic> m) =>
    (m["type"] ?? "") == "invite" &&
        _inviteStatus(m) != "applied" &&
        _inviteStatus(m) != "declined" &&
        _inviteStatus(m) != "withdrawn";

void showInviteDialog(BuildContext context, Map<String, dynamic> data) {
  final nav = Navigator.of(context);
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Invitation",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (dialogContext, _, __) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: AppColors.background,
                child: _InviteDetails(
                  data: data,
                  dialogContext: dialogContext,
                  nav: nav,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _Matched {
  final String title;
  final String? id;
  final Map<String, dynamic>? doc;
  final bool mine;
  _Matched({required this.title, this.id, this.doc, this.mine = false});
}

class _InviteDetails extends StatefulWidget {
  final Map<String, dynamic> data;
  final BuildContext dialogContext;
  final NavigatorState nav;

  const _InviteDetails({
    required this.data,
    required this.dialogContext,
    required this.nav,
  });

  @override
  State<_InviteDetails> createState() => _InviteDetailsState();
}

class _InviteDetailsState extends State<_InviteDetails> {
  final List<StreamSubscription> _subs = [];

  Map<String, dynamic>? _sponsor;
  Map<String, dynamic> _student = {};
  final Map<int, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _chunks =
  {};
  Set<String> _appliedIds = {};
  String? _liveStatus;
  bool _schLoaded = false;
  final Set<String> _open = {};
  bool _responding = false;
  String? _error;

  List<String> get _titles => (widget.data["scholarshipTitles"] is List)
      ? (widget.data["scholarshipTitles"] as List)
      .map((e) => e.toString())
      .toList()
      : <String>[];

  String get _sponsorId => (widget.data["sponsorId"] ?? "").toString();

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _safe(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // Everything below is LIVE (Firestore snapshots) - edits by the sponsor,
  // a new application by the student etc. reflect instantly in this view.
  void _listen() {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (_sponsorId.isNotEmpty) {
      _subs.add(db.collection("users").doc(_sponsorId).snapshots().listen(
            (s) => _safe(() => _sponsor = s.data()),
        onError: (e) => debugPrint("INVITE sponsor stream: $e"),
      ));
    }

    if (uid != null) {
      _subs.add(db.collection("users").doc(uid).snapshots().listen(
            (s) => _safe(() => _student = s.data() ?? {}),
        onError: (e) => debugPrint("INVITE student stream: $e"),
      ));

      _subs.add(db
          .collection("applications")
          .where("studentId", isEqualTo: uid)
          .snapshots()
          .listen(
            (snap) {
          final ids = <String>{};
          for (final d in snap.docs) {
            final id = d.data()["scholarshipId"];
            if (id != null) ids.add(id.toString());
          }
          _safe(() => _appliedIds = ids);
        },
        onError: (e) => debugPrint("INVITE applications stream: $e"),
      ));

      if (_sponsorId.isNotEmpty) {
        _subs.add(db
            .collection("notifications")
            .doc("invite_${_sponsorId}_$uid")
            .snapshots()
            .listen(
              (s) => _safe(() => _liveStatus = s.data()?["status"]?.toString()),
          onError: (e) => debugPrint("INVITE status stream: $e"),
        ));
      }
    }

    final titles = _titles;
    if (titles.isEmpty) _schLoaded = true;
    for (var i = 0; i < titles.length; i += 10) {
      final idx = i ~/ 10;
      final chunk = titles.sublist(i, math.min(i + 10, titles.length));
      _subs.add(db
          .collection("scholarships")
          .where("title", whereIn: chunk)
          .snapshots()
          .listen(
            (snap) => _safe(() {
          _chunks[idx] = snap.docs;
          _schLoaded = true;
        }),
        onError: (e) {
          debugPrint("INVITE scholarships stream: $e");
          _safe(() => _schLoaded = true);
        },
      ));
    }
  }

  List<_Matched> get _items {
    final found = <String, _Matched>{};
    for (final docs in _chunks.values) {
      for (final d in docs) {
        final m = d.data();
        final t = (m["title"] ?? "").toString();
        final owner =
        _firstText(m, ["sponsorId", "sponsorUid", "createdBy", "ownerId"]);
        final mine =
            owner.isEmpty || _sponsorId.isEmpty || owner == _sponsorId;
        final old = found[t];
        if (old == null || (mine && !old.mine)) {
          found[t] = _Matched(title: t, id: d.id, doc: m, mine: mine);
        }
      }
    }
    return [for (final t in _titles) found[t] ?? _Matched(title: t)];
  }

  bool? _eligible(Map<String, dynamic>? sch) {
    if (sch == null || _student.isEmpty) return null;
    try {
      return isStudentEligibleForScholarship(sch, _student);
    } catch (e) {
      debugPrint("INVITE eligibility error: $e");
      return null;
    }
  }

  void _close() => Navigator.pop(widget.dialogContext);

  // "Full details" -> the app's normal scholarship details page
  void _openDetails(String id) {
    _close();
    widget.nav.push(
      MaterialPageRoute(
        builder: (_) => ScholarshipInfoScreen(scholarshipId: id),
      ),
    );
  }

  // "Apply Now" -> straight into the documents + SOP apply form
  void _applyTo(String id, Map<String, dynamic> d) {
    _close();
    widget.nav.push(
      MaterialPageRoute(builder: (_) => _applicationForm(id, d)),
    );
  }

  void _browse() {
    _close();
    widget.nav.push(
      MaterialPageRoute(builder: (_) => const AllScholarshipsScreen()),
    );
  }

  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final gold = AppColors.secondary;
    final navy = AppColors.primary;

    final fallbackName = (widget.data["sponsorName"] ?? "A sponsor").toString();
    final org = _firstText(_sponsor,
        ["organization", "organizationName", "orgName", "companyName"]);
    final person = _firstText(_sponsor, ["name", "fullName", "userName"]);
    final orgTitle =
    org.isNotEmpty ? org : (person.isNotEmpty ? person : fallbackName);
    final orgType = _firstText(
        _sponsor, ["organizationType", "orgType", "sponsorType", "category"]);
    final email = _firstText(_sponsor, ["email"]);
    final phone =
    _firstText(_sponsor, ["phone", "phoneNumber", "mobile", "contact"]);
    final website = _firstText(_sponsor, ["website", "websiteUrl"]);
    final location =
    _firstText(_sponsor, ["address", "location", "city", "state"]);
    final about = _firstText(_sponsor, ["about", "description", "bio"]);

    final status = _liveStatus ?? (widget.data["status"] ?? "invited").toString();
    final applied = status == "applied";
    final accepted = status == "accepted" || applied;
    final declined = status == "declined";
    final withdrawn = status == "withdrawn";
    final sponsorLoading = _sponsor == null && _sponsorId.isNotEmpty;
    final items = _items;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---------- header ----------
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 14, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navy, navy.withOpacity(0.86)],
            ),
            border: Border(bottom: BorderSide(color: gold, width: 3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gold,
                    boxShadow: [
                      BoxShadow(color: gold.withOpacity(0.5), blurRadius: 16),
                    ],
                  ),
                  child: Text(
                    orgTitle.isNotEmpty ? orgTitle[0].toUpperCase() : "S",
                    style: TextStyle(
                      color: navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "SCHOLARSHIP INVITATION",
                        style: TextStyle(
                          color: gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      orgTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "has invited you to apply",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _close,
                icon: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
        ),

        // ---------- body ----------
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accepted && !applied)
                  FadeSlideIn(
                    child: _statusStrip(
                      Icons.celebration_rounded,
                      AppColors.success,
                      "Invitation accepted! Choose a scholarship below and apply.",
                    ),
                  ),
                if (withdrawn)
                  FadeSlideIn(
                    child: _statusStrip(
                      Icons.undo_rounded,
                      AppColors.textSecondary,
                      "The sponsor has withdrawn this invitation.",
                    ),
                  ),
                if (declined)
                  FadeSlideIn(
                    child: _statusStrip(
                      Icons.info_rounded,
                      AppColors.error,
                      "You declined this invitation. You can still accept it below.",
                    ),
                  ),
                if (applied)
                  FadeSlideIn(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "You have applied. The sponsor has been notified.",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: Text(
                    (widget.data["body"] ?? "").toString(),
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ----- sponsor details -----
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("ABOUT THE SPONSOR"),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: _boxDeco(),
                        child: sponsorLoading
                            ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4),
                            ),
                          ),
                        )
                            : Column(
                          children: [
                            _InfoRow(
                                icon: Icons.apartment_rounded,
                                label: "Organisation",
                                value: org.isNotEmpty ? org : orgTitle),
                            _InfoRow(
                                icon: Icons.category_rounded,
                                label: "Type",
                                value: orgType),
                            _InfoRow(
                                icon: Icons.person_rounded,
                                label: "Contact person",
                                value: person == orgTitle ? "" : person),
                            _InfoRow(
                                icon: Icons.email_rounded,
                                label: "Email",
                                value: email),
                            _InfoRow(
                                icon: Icons.phone_rounded,
                                label: "Phone",
                                value: phone),
                            _InfoRow(
                                icon: Icons.language_rounded,
                                label: "Website",
                                value: website),
                            _InfoRow(
                                icon: Icons.location_on_rounded,
                                label: "Location",
                                value: location),
                            _InfoRow(
                                icon: Icons.info_outline_rounded,
                                label: "About",
                                value: about),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ----- matched scholarships -----
                Row(
                  children: [
                    _sectionLabel("SCHOLARSHIPS YOU MATCH (${_titles.length})"),
                    const SizedBox(width: 10),
                    if (accepted) const _LiveDot(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  accepted
                      ? "Tap a scholarship to see its requirements and apply."
                      : "Accept the invitation to unlock the requirements and apply.",
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                if (!accepted)
                  for (final t in _titles) _lockedTile(t)
                else if (!_schLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < items.length; i++)
                    _scholarshipTile(items[i], i),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ---------- footer ----------
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(color: Colors.black.withOpacity(0.06)),
            ),
          ),
          child: withdrawn
              ? Row(children: [
            TextButton(onPressed: _close, child: const Text("Close")),
          ])
              : !accepted
              ? _respondBar(declined)
              : Row(
            children: [
              TextButton(onPressed: _close, child: const Text("Close")),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _browse,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text("Browse Scholarships"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusStrip(IconData icon, Color color, String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _lockedTile(String title) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: _boxDeco(),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.lock_rounded, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    ),
  );

  Future<void> _respond(bool accept) async {
    if (_responding) return;
    setState(() {
      _responding = true;
      _error = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final name = _firstText(_student, ["name", "fullName", "userName"]);
    String? err;
    try {
      err = await NotificationService().respondToInvite(
        sponsorId: _sponsorId,
        studentId: uid,
        studentName: name.isEmpty ? "A student" : name,
        accept: accept,
        scholarshipTitles: _titles,
      );
    } catch (e) {
      err = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _responding = false;
      _error = err;
    });
    // Accepted: the live status stream flips the view to "unlocked".
    if (err == null && !accept) _close();
  }

  Widget _respondBar(bool declined) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!,
                style: TextStyle(color: AppColors.error, fontSize: 12.5)),
          ),
        Row(
          children: [
            if (declined)
              TextButton(onPressed: _close, child: const Text("Close"))
            else
              TextButton(
                onPressed: _responding ? null : () => _respond(false),
                child: Text("Decline",
                    style: TextStyle(color: AppColors.error)),
              ),
            const Spacer(),
            _PulseGlow(
              active: !_responding,
              radius: 12,
              margin: EdgeInsets.zero,
              child: ElevatedButton.icon(
                onPressed: _responding ? null : () => _respond(true),
                icon: _responding
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text("Accept Invitation",
                    style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  BoxDecoration _boxDeco({Color? border}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: border ?? Colors.black.withOpacity(0.06)),
  );

  Widget _sectionLabel(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.9,
      color: AppColors.secondary,
    ),
  );

  // ---------------------------------------------------------
  // One scholarship: collapsed summary + expandable requirements
  // ---------------------------------------------------------
  Widget _scholarshipTile(_Matched it, int index) {
    final d = it.doc;
    final key = it.id ?? it.title;
    final isOpen = _open.contains(key);

    final amount = _firstText(d, ["amount"]);
    final deadline = _firstText(d, ["lastDate", "deadline"]);
    final cat = _firstText(d, ["scholarshipType", "category", "type"]);

    final applied = it.id != null && _appliedIds.contains(it.id);
    final elig = _eligible(d);

    String? badge;
    Color badgeColor = AppColors.primary;
    IconData badgeIcon = Icons.check_circle_rounded;
    if (applied) {
      badge = "Applied";
      badgeColor = AppColors.primary;
      badgeIcon = Icons.task_alt_rounded;
    } else if (elig == true) {
      badge = "You're eligible";
      badgeColor = AppColors.success;
    } else if (elig == false) {
      badge = "Not eligible";
      badgeColor = AppColors.error;
      badgeIcon = Icons.info_rounded;
    }

    return FadeSlideIn(
      delay: Duration(milliseconds: 90 * (index + 3)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: _boxDeco(
          border: isOpen
              ? AppColors.secondary.withOpacity(0.7)
              : Colors.black.withOpacity(0.06),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: d == null
                  ? null
                  : () => setState(() {
                isOpen ? _open.remove(key) : _open.add(key);
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                      Icon(Icons.school_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              if (amount.isNotEmpty)
                                _miniInfo(
                                    Icons.currency_rupee_rounded, amount),
                              if (deadline.isNotEmpty)
                                _miniInfo(Icons.event_rounded,
                                    "Last date $deadline"),
                              if (cat.isNotEmpty)
                                _miniInfo(Icons.label_rounded, cat),
                            ],
                          ),
                          if (badge != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badgeIcon,
                                      size: 13, color: badgeColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    badge,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (d != null)
                      AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isOpen
                  ? _tileDetails(it, applied: applied, elig: elig)
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileDetails(_Matched it,
      {required bool applied, required bool? elig}) {
    final d = it.doc ?? {};
    final reqs = _requirements(d);
    final docs = _requiredDocs(d);
    final desc = _firstText(d, ["description", "about", "details"]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.black.withOpacity(0.08), height: 1),
          const SizedBox(height: 12),
          if (desc.isNotEmpty) ...[
            Text(desc,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
          ],
          if (reqs.isNotEmpty) ...[
            _sectionLabel("ELIGIBILITY REQUIREMENTS"),
            const SizedBox(height: 6),
            for (final r in reqs)
              _InfoRow(icon: r.icon, label: r.label, value: r.value),
            const SizedBox(height: 10),
          ],
          if (docs.isNotEmpty) ...[
            _sectionLabel("DOCUMENTS TO UPLOAD"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final doc in docs)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(doc,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (reqs.isEmpty && docs.isEmpty && desc.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "The sponsor has not listed detailed requirements. "
                    "Open the full details to read more.",
                style:
                TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
          if (elig == false)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Your profile does not meet the criteria for this "
                    "scholarship.",
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error),
              ),
            ),
          Row(
            children: [
              if (it.id != null)
                OutlinedButton.icon(
                  onPressed: () => _openDetails(it.id!),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text("Full details"),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              const Spacer(),
              if (applied)
                ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.task_alt_rounded, size: 17),
                  label: const Text("Already applied"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                )
              else if (elig != false && it.id != null)
                ElevatedButton.icon(
                  onPressed: () => _applyTo(it.id!, it.doc ?? {}),
                  icon: const Icon(Icons.send_rounded, size: 17),
                  label: const Text("Apply Now"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(text,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style:
              const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// Requirement fields. Several common field names are tried for each row,
// only the ones that exist in the scholarship document are shown.
List<({IconData icon, String label, String value})> _requirements(
    Map<String, dynamic> d) {
  final specs = <(IconData, String, List<String>)>[
    (Icons.grade_rounded, "Minimum marks", [
      "minPercentage", "minMarks", "minimumPercentage", "minCgpa",
      "minGpa", "cgpa", "percentage", "marksRequired", "minAcademicScore"
    ]),
    (Icons.account_balance_wallet_rounded, "Max family income", [
      "maxIncome", "incomeLimit", "maxFamilyIncome", "familyIncome",
      "annualIncome", "incomeCeiling"
    ]),
    (Icons.menu_book_rounded, "Course / Branch", [
      "course", "courses", "branch", "branches", "department",
      "eligibleCourses"
    ]),
    (Icons.timeline_rounded, "Year of study", [
      "year", "yearOfStudy", "eligibleYear", "eligibleYears"
    ]),
    (Icons.workspace_premium_rounded, "Education level", [
      "educationLevel", "level", "degree", "qualification"
    ]),
    (Icons.wc_rounded, "Gender", ["gender"]),
    (Icons.groups_rounded, "Community", [
      "community", "caste", "reservation", "eligibleCommunity"
    ]),
    (Icons.location_city_rounded, "State / Region", ["state", "region"]),
    (Icons.rule_rounded, "Other criteria", [
      "eligibility", "eligibilityCriteria", "criteria", "requirements",
      "terms"
    ]),
  ];

  final out = <({IconData icon, String label, String value})>[];
  for (final s in specs) {
    var v = _firstText(d, s.$3);
    if (v.isEmpty) continue;
    if (s.$2 == "Max family income" && !v.startsWith("₹")) v = "₹$v";
    out.add((icon: s.$1, label: s.$2, value: v));
  }
  return out;
}

List<String> _requiredDocs(Map<String, dynamic> d) {
  for (final k in [
    "requiredDocuments", "requiredDocs", "documentsRequired", "documents"
  ]) {
    final v = d[k];
    if (v is List && v.isNotEmpty) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (v is String && v.trim().isNotEmpty) {
      return v
          .split(RegExp(r"[,\n;]"))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  return [];
}


// =========================================================
// FULL SCHOLARSHIP DETAILS (opened from an invitation) + APPLY BUTTON
// =========================================================

DateTime? _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) {
    final p = v.trim().split(RegExp(r"[/\-.]"));
    if (p.length == 3) {
      final a = int.tryParse(p[0]);
      final b = int.tryParse(p[1]);
      final c = int.tryParse(p[2]);
      if (a != null && b != null && c != null) {
        if (p[0].length == 4) return DateTime(a, b, c); // yyyy-mm-dd
        return DateTime(c, b, a); // dd/mm/yyyy
      }
    }
  }
  return null;
}

Widget _sectionTitle(String t) => Text(
  t,
  style: TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.9,
    color: AppColors.secondary,
  ),
);

class InviteScholarshipDetailsScreen extends StatelessWidget {
  final String scholarshipId;
  final String? sponsorName;

  const InviteScholarshipDetailsScreen({
    super.key,
    required this.scholarshipId,
    this.sponsorName,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection("scholarships").doc(scholarshipId).snapshots(),
        builder: (context, schSnap) {
          if (schSnap.hasError) {
            return _message(context, "Could not load this scholarship.\n"
                "${schSnap.error}");
          }
          if (!schSnap.hasData) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final d = schSnap.data!.data();
          if (d == null) {
            return _message(
                context, "This scholarship is no longer available.");
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: uid == null ? null : db.collection("users").doc(uid).snapshots(),
            builder: (context, stuSnap) {
              final student = stuSnap.data?.data() ?? {};

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: uid == null
                    ? null
                    : db
                    .collection("applications")
                    .where("studentId", isEqualTo: uid)
                    .snapshots(),
                builder: (context, appSnap) {
                  final applied = (appSnap.data?.docs ?? []).any((a) =>
                  a.data()["scholarshipId"]?.toString() == scholarshipId);
                  return _content(context, d, student, applied);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _message(BuildContext context, String text) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(text,
                    textAlign: TextAlign.center, style: AppTextStyles.subtitle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> d,
      Map<String, dynamic> student, bool applied) {
    final title = _firstText(d, ["title"]);
    final amount = _firstText(d, ["amount"]);
    final lastDateText = _firstText(d, ["lastDate", "deadline"]);
    final cat = _firstText(d, ["scholarshipType", "category", "type"]);
    final desc = _firstText(d, ["description", "about", "details"]);
    final reqs = _requirements(d);
    final docs = _requiredDocs(d);

    final last = _parseDate(d["lastDate"] ?? d["deadline"]);
    final today = DateTime.now();
    final closed = last != null &&
        DateTime(last.year, last.month, last.day)
            .isBefore(DateTime(today.year, today.month, today.day));
    final daysLeft = last == null
        ? null
        : DateTime(last.year, last.month, last.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    bool? eligible;
    if (student.isNotEmpty) {
      try {
        eligible = isStudentEligibleForScholarship(d, student);
      } catch (e) {
        debugPrint("DETAILS eligibility error: $e");
      }
    }

    final canApply = !applied && !closed && eligible != false;

    String statusText;
    Color statusColor;
    IconData statusIcon;
    if (applied) {
      statusText = "You have already applied";
      statusColor = AppColors.primary;
      statusIcon = Icons.task_alt_rounded;
    } else if (closed) {
      statusText = "Applications are closed";
      statusColor = AppColors.error;
      statusIcon = Icons.event_busy_rounded;
    } else if (eligible == false) {
      statusText = "You don't meet the criteria";
      statusColor = AppColors.error;
      statusIcon = Icons.info_rounded;
    } else if (eligible == true) {
      statusText = "You're eligible to apply";
      statusColor = AppColors.success;
      statusIcon = Icons.verified_rounded;
    } else {
      statusText = "Check the requirements below";
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.rule_rounded;
    }

    final sponsor = sponsorName ??
        _firstText(d, ["sponsorName", "organization", "organizationName"]);

    Widget card(List<Widget> children) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

    Widget chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );

    return Column(
      children: [
        // ---------- header ----------
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.84)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            border: Border(
                bottom: BorderSide(color: AppColors.secondary, width: 3)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                          ),
                          Text(
                            "Scholarship Details",
                            style: AppTextStyles.title.copyWith(
                                fontSize: 16, color: Colors.white),
                          ),
                          const Spacer(),
                          const _LiveDot(),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6),
                        child: FadeSlideIn(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (sponsor.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text("by $sponsor",
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 13)),
                              ],
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  if (amount.isNotEmpty)
                                    chip(Icons.currency_rupee_rounded, amount),
                                  if (lastDateText.isNotEmpty)
                                    chip(Icons.event_rounded,
                                        "Last date $lastDateText"),
                                  if (cat.isNotEmpty)
                                    chip(Icons.label_rounded, cat),
                                  if (daysLeft != null)
                                    chip(
                                      Icons.hourglass_bottom_rounded,
                                      closed
                                          ? "Closed"
                                          : (daysLeft == 0
                                          ? "Last day today"
                                          : "$daysLeft days left"),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ---------- body ----------
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    children: [
                      if (desc.isNotEmpty)
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 80),
                          child: card([
                            _sectionTitle("ABOUT THIS SCHOLARSHIP"),
                            const SizedBox(height: 10),
                            Text(desc,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.5,
                                    color: AppColors.textPrimary)),
                          ]),
                        ),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        child: card([
                          _sectionTitle("ELIGIBILITY REQUIREMENTS"),
                          const SizedBox(height: 8),
                          if (reqs.isEmpty)
                            Text(
                              "The sponsor has not listed detailed requirements.",
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary),
                            )
                          else
                            for (final r in reqs)
                              _InfoRow(
                                  icon: r.icon,
                                  label: r.label,
                                  value: r.value),
                        ]),
                      ),
                      if (docs.isNotEmpty)
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 240),
                          child: card([
                            _sectionTitle("DOCUMENTS TO UPLOAD"),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final doc in docs)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 7),
                                    decoration: BoxDecoration(
                                      color:
                                      AppColors.primary.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.description_rounded,
                                            size: 15,
                                            color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text(doc,
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight:
                                                FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ]),
                        ),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 320),
                        child: card([
                          _sectionTitle("HOW TO APPLY"),
                          const SizedBox(height: 12),
                          _step(1, "Check your eligibility",
                              "Make sure you meet every requirement above."),
                          _step(2, "Upload your documents",
                              "Keep the listed documents ready as clear PDFs or images."),
                          _step(3, "Write your statement of purpose",
                              "Briefly explain why you deserve this scholarship."),
                          _step(4, "Submit & track",
                              "Follow verification and approval status in My Applications."),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ---------- sticky apply bar ----------
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PulseGlow(
                      active: canApply,
                      radius: 14,
                      margin: EdgeInsets.zero,
                      child: ElevatedButton.icon(
                        onPressed:
                        canApply ? () => _confirmApply(context, docs, d) : null,
                        icon: Icon(
                            applied
                                ? Icons.task_alt_rounded
                                : Icons.send_rounded,
                            size: 18),
                        label: Text(
                          applied
                              ? "Already Applied"
                              : (closed
                              ? "Applications Closed"
                              : (eligible == false
                              ? "Not Eligible"
                              : "Apply for this Scholarship")),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.black12,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _step(int n, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text("$n",
              style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    ),
  );

  // Pre-apply checklist, then continue into the existing apply flow.
  void _confirmApply(
      BuildContext context, List<String> docs, Map<String, dynamic> d) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Ready to apply?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Keep these ready before you continue:"),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              const Text("• Your academic and income documents")
            else
              for (final d in docs) Text("• $d"),
            const SizedBox(height: 10),
            const Text("• A short statement of purpose"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Not now"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _startApply(context, d);
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  void _startApply(BuildContext context, Map<String, dynamic> d) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _applicationForm(scholarshipId, d)),
    );
  }
}

// =========================================================
// BLINKING CHIP  ("NEW INVITATION" on the list card)
// =========================================================

class _BlinkChip extends StatefulWidget {
  final String text;
  const _BlinkChip(this.text);

  @override
  State<_BlinkChip> createState() => _BlinkChipState();
}

class _BlinkChipState extends State<_BlinkChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.text,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// =========================================================
// SMALL ANIMATION HELPERS
// =========================================================

/// Fade + slide-up entrance. Use it anywhere: FadeSlideIn(delay: ..., child: ...)
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double dy; // fraction of the child's height

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.dy = 0.12,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _go = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) setState(() => _go = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _go ? 1 : 0,
      duration: widget.duration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _go ? Offset.zero : Offset(0, widget.dy),
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Tiny blinking green dot + "LIVE" label (data updates in real time)
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text("LIVE",
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.success)),
        ],
      ),
    );
  }
}

// =========================================================
// PULSING GOLD GLOW (used for unread invitation cards)
// =========================================================

class _PulseGlow extends StatefulWidget {
  final bool active;
  final Widget child;
  final double radius;
  final EdgeInsets margin;
  const _PulseGlow({
    required this.active,
    required this.child,
    this.radius = 18,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<_PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<_PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        margin: widget.margin,
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.40 + 0.50 * t),
                blurRadius: 14 + 22 * t,
                spreadRadius: 2 + 4 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// =========================================================
// SPONSOR SIDE: professional, live invitation tracker
// Opens from sponsor notifications:
//   Invitation accepted / declined, Invited student applied
// =========================================================

const List<String> _monthNames = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

String _fmtStamp(dynamic v) {
  if (v is! Timestamp) return "";
  final d = v.toDate();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, "0");
  return "${d.day} ${_monthNames[d.month - 1]}, $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}";
}

enum _StepState { done, current, pending, failed }

void showSponsorInviteDialog(BuildContext context, Map<String, dynamic> data) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Invitation tracker",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (dialogContext, _, __) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 740),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: AppColors.background,
                child: _SponsorInviteView(
                  data: data,
                  dialogContext: dialogContext,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _SponsorInviteView extends StatefulWidget {
  final Map<String, dynamic> data;
  final BuildContext dialogContext;
  const _SponsorInviteView({required this.data, required this.dialogContext});

  @override
  State<_SponsorInviteView> createState() => _SponsorInviteViewState();
}

class _SponsorInviteViewState extends State<_SponsorInviteView> {
  final List<StreamSubscription> _subs = [];
  Map<String, dynamic>? _invite;
  Map<String, dynamic>? _student;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _apps = [];

  bool _busy = false;
  String? _msg;
  bool _msgOk = false;

  String get _me => FirebaseAuth.instance.currentUser?.uid ?? "";
  String get _studentId => (widget.data["studentId"] ?? "").toString();

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _safe(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _listen() {
    if (_me.isEmpty || _studentId.isEmpty) return;
    final db = FirebaseFirestore.instance;

    _subs.add(db
        .collection("notifications")
        .doc("invite_${_me}_$_studentId")
        .snapshots()
        .listen((s) => _safe(() => _invite = s.data()),
        onError: (e) => debugPrint("TRACKER invite stream: $e")));

    _subs.add(db.collection("users").doc(_studentId).snapshots().listen(
            (s) => _safe(() => _student = s.data()),
        onError: (e) => debugPrint("TRACKER student stream: $e")));

    _subs.add(db
        .collection("applications")
        .where("sponsorId", isEqualTo: _me)
        .where("studentId", isEqualTo: _studentId)
        .snapshots()
        .listen((s) => _safe(() => _apps = s.docs),
        onError: (e) => debugPrint("TRACKER applications stream: $e")));
  }

  void _close() => Navigator.pop(widget.dialogContext);

  String get _status {
    final live = _invite?["status"]?.toString();
    if (live != null && live.isNotEmpty) return live;
    switch ((widget.data["type"] ?? "").toString()) {
      case "invite_applied":
        return "applied";
      case "invite_accepted":
        return "accepted";
      case "invite_declined":
        return "declined";
      default:
        return "invited";
    }
  }

  Future<void> _remind() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = await NotificationService()
        .sendInviteReminder(sponsorId: _me, studentId: _studentId);
    _safe(() {
      _busy = false;
      _msgOk = err == null;
      _msg = err ?? "Reminder sent to the student ✅";
    });
  }

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Withdraw invitation?"),
        content: const Text(
            "The student will no longer see this invitation and becomes "
                "available to other sponsors again."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Keep")),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child:
            Text("Withdraw", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = await NotificationService()
        .withdrawInvite(sponsorId: _me, studentId: _studentId);
    _safe(() {
      _busy = false;
      _msgOk = err == null;
      _msg = err ?? "Invitation withdrawn.";
    });
  }

  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final navy = AppColors.primary;
    final gold = AppColors.secondary;
    final st = _student;
    final status = _status;

    final name = _firstText(st, ["name", "fullName", "userName"]).isNotEmpty
        ? _firstText(st, ["name", "fullName", "userName"])
        : (widget.data["studentName"] ?? "Student").toString();
    final college =
    _firstText(st, ["college", "collegeName", "institution", "institute"]);
    final course = _firstText(st, ["course", "branch", "department"]);

    Color sColor;
    String sLabel;
    IconData sIcon;
    switch (status) {
      case "accepted":
        sColor = AppColors.success;
        sLabel = "ACCEPTED";
        sIcon = Icons.check_circle_rounded;
        break;
      case "applied":
        sColor = AppColors.success;
        sLabel = "APPLIED";
        sIcon = Icons.task_alt_rounded;
        break;
      case "declined":
        sColor = AppColors.error;
        sLabel = "DECLINED";
        sIcon = Icons.cancel_rounded;
        break;
      case "withdrawn":
        sColor = AppColors.textSecondary;
        sLabel = "WITHDRAWN";
        sIcon = Icons.undo_rounded;
        break;
      default:
        sColor = gold;
        sLabel = "AWAITING RESPONSE";
        sIcon = Icons.hourglass_top_rounded;
    }

    final canAct = status == "invited" || status == "accepted";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---------- header ----------
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 20, 12, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navy, navy.withOpacity(0.86)],
            ),
            border: Border(bottom: BorderSide(color: gold, width: 3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gold,
                    boxShadow: [
                      BoxShadow(color: gold.withOpacity(0.5), blurRadius: 16),
                    ],
                  ),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "S",
                    style: TextStyle(
                        color: navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sIcon, size: 14, color: sColor),
                          const SizedBox(width: 5),
                          Text(sLabel,
                              style: TextStyle(
                                  color: sColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    if (college.isNotEmpty || course.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        [course, college].where((e) => e.isNotEmpty).join("  •  "),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: _close,
                icon: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
        ),

        // ---------- body ----------
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(
                  child: Text(
                    (widget.data["body"] ?? "").toString(),
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 18),

                // tracker
                FadeSlideIn(
                  delay: const Duration(milliseconds: 90),
                  child: _panel("INVITATION TRACKER", _timeline(status)),
                ),

                // applications from this student
                if (_apps.isNotEmpty)
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: _panel(
                      "APPLICATIONS (${_apps.length})",
                      Column(children: [for (final a in _apps) _appTile(a)]),
                    ),
                  ),

                // student snapshot
                FadeSlideIn(
                  delay: const Duration(milliseconds: 270),
                  child: _panel(
                    "STUDENT SNAPSHOT",
                    _snapshot(st, status == "accepted" || status == "applied"),
                  ),
                ),

                // matched scholarships
                if (_matched.isNotEmpty)
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 360),
                    child: _panel(
                      "MATCHED SCHOLARSHIPS (${_matched.length})",
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in _matched)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _appliedTitles.contains(t)
                                        ? Icons.check_circle_rounded
                                        : Icons.school_rounded,
                                    size: 14,
                                    color: _appliedTitles.contains(t)
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(t,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),

        // ---------- footer ----------
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
                top: BorderSide(color: Colors.black.withOpacity(0.06))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _msg == null
                    ? const SizedBox(width: double.infinity, height: 0)
                    : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _msg!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _msgOk ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton(onPressed: _close, child: const Text("Close")),
                  const Spacer(),
                  if (canAct) ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _withdraw,
                      icon: const Icon(Icons.undo_rounded, size: 17),
                      label: const Text("Withdraw"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                            color: AppColors.error.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _remind,
                      icon: _busy
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.notifications_active_rounded,
                          size: 17),
                      label: const Text("Send Reminder",
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: gold,
                        foregroundColor: navy,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> get _matched => (_invite?["scholarshipTitles"] is List)
      ? (_invite!["scholarshipTitles"] as List).map((e) => e.toString()).toList()
      : <String>[];

  Set<String> get _appliedTitles {
    final out = <String>{};
    if (_invite?["appliedTitles"] is List) {
      out.addAll((_invite!["appliedTitles"] as List).map((e) => e.toString()));
    }
    for (final a in _apps) {
      final t = (a.data()["scholarshipTitle"] ?? "").toString();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  Widget _panel(String title, Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black.withOpacity(0.05)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  // ---------- animated Invited -> Accepted -> Applied ----------
  Widget _timeline(String status) {
    final declined = status == "declined";
    final withdrawn = status == "withdrawn";
    final applied = status == "applied";
    final accepted = status == "accepted" || applied;

    final secondLabel =
    declined ? "Declined" : (withdrawn ? "Withdrawn" : "Accepted");
    final secondState = (declined || withdrawn)
        ? _StepState.failed
        : (accepted ? _StepState.done : _StepState.current);
    final thirdState = applied
        ? _StepState.done
        : (accepted ? _StepState.current : _StepState.pending);

    Widget connector(bool filled) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 17),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: filled ? 1 : 0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, v, _) => Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepNode(0, "Invited", _fmtStamp(_invite?["createdAt"]),
            _StepState.done, Icons.send_rounded),
        connector(accepted || declined),
        _stepNode(
            1,
            secondLabel,
            _fmtStamp(_invite?["respondedAt"]),
            secondState,
            declined
                ? Icons.close_rounded
                : (withdrawn ? Icons.undo_rounded : Icons.thumb_up_alt_rounded)),
        connector(applied),
        _stepNode(2, "Applied", _fmtStamp(_invite?["appliedAt"]), thirdState,
            Icons.description_rounded),
      ],
    );
  }

  Widget _stepNode(
      int index, String label, String time, _StepState state, IconData icon) {
    Color bg;
    Widget inner;
    switch (state) {
      case _StepState.done:
        bg = AppColors.success;
        inner = const Icon(Icons.check_rounded, color: Colors.white, size: 20);
        break;
      case _StepState.failed:
        bg = AppColors.error;
        inner = Icon(icon, color: Colors.white, size: 19);
        break;
      case _StepState.current:
        bg = AppColors.secondary;
        inner = Icon(icon, color: AppColors.primary, size: 18);
        break;
      default:
        bg = Colors.black.withOpacity(0.10);
        inner = Icon(icon, color: AppColors.textSecondary, size: 17);
    }

    Widget node = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: inner,
    );
    if (state == _StepState.current) {
      node = _PulseGlow(
        active: true,
        radius: 18,
        margin: EdgeInsets.zero,
        child: node,
      );
    }

    return SizedBox(
      width: 86,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 500 + index * 250),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(
          scale: v.clamp(0.0, 1.2),
          child: child,
        ),
        child: Column(
          children: [
            node,
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: state == _StepState.pending
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                )),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(time,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10.5, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- student snapshot ----------
  Widget _snapshot(Map<String, dynamic>? st, bool revealContact) {
    if (st == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    final pctText = _firstText(st, ["percentage", "cgpa", "marks"]);
    final pct = double.tryParse(pctText.replaceAll("%", "").trim());
    final year = _firstText(st, ["year", "yearOfStudy"]);
    final cat = _firstText(st, ["category", "community"]);
    final city = _firstText(st, ["city", "district"]);
    final state = _firstText(st, ["state"]);
    final location = [city, state].where((e) => e.isNotEmpty).join(", ");
    final income =
    _firstText(st, ["annualIncome", "familyIncome", "income"]);
    final email = _firstText(st, ["email"]);
    final phone = _firstText(st, ["phone", "phoneNumber", "mobile"]);

    Widget stat(IconData icon, String label, Widget value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              value,
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );

    const valStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w900);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (pct != null)
              stat(
                Icons.grade_rounded,
                "Academic score",
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    "${v.toStringAsFixed(1)}${pctText.contains('%') || pct > 10 ? '%' : ''}",
                    style: valStyle,
                  ),
                ),
              ),
            if (year.isNotEmpty)
              stat(Icons.timeline_rounded, "Year", Text(year, style: valStyle)),
            if (cat.isNotEmpty)
              stat(Icons.groups_rounded, "Category",
                  Text(cat, style: valStyle)),
          ],
        ),
        const SizedBox(height: 8),
        _InfoRow(
            icon: Icons.location_on_rounded,
            label: "Location",
            value: location),
        _InfoRow(
            icon: Icons.account_balance_wallet_rounded,
            label: "Family income",
            value: income.isEmpty || income.startsWith("₹") ? income : "₹$income"),
        if (revealContact) ...[
          _InfoRow(icon: Icons.email_rounded, label: "Email", value: email),
          _InfoRow(icon: Icons.phone_rounded, label: "Phone", value: phone),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.lock_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Contact details are shown once the student accepts.",
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _appTile(QueryDocumentSnapshot<Map<String, dynamic>> a) {
    final m = a.data();
    final title = (m["scholarshipTitle"] ?? "Scholarship").toString();
    final status = (m["status"] ?? "Pending").toString();
    final verified = m["documentsVerified"] == true;

    Color c;
    switch (status.toLowerCase()) {
      case "approved":
        c = AppColors.success;
        break;
      case "rejected":
        c = AppColors.error;
        break;
      default:
        c = AppColors.secondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.description_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  verified ? "Documents verified" : "Documents not verified yet",
                  style: TextStyle(
                      fontSize: 11.5,
                      color: verified
                          ? AppColors.success
                          : AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status,
                style: TextStyle(
                    color: c, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// DASHBOARD INVITATION CARDS  (every pending invitation, glowing)
// Add to the student dashboard:  const InviteHighlightCard()
// A card disappears once the student applies or declines.
// =========================================================

class InviteHighlightCard extends StatefulWidget {
  const InviteHighlightCard({super.key});

  @override
  State<InviteHighlightCard> createState() => _InviteHighlightCardState();
}

class _InviteHighlightCardState extends State<InviteHighlightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NotificationService().streamFor(uid),
      builder: (context, snap) {
        final invites = (snap.data?.docs ?? []).where((d) {
          final m = d.data();
          return (m["audience"] ?? "student") == "student" &&
              _isPendingInvite(m);
        }).toList();

        if (invites.isEmpty) return const SizedBox.shrink();

        DateTime ts(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final t = d.data()["createdAt"];
          return t is Timestamp ? t.toDate() : DateTime.now();
        }

        invites.sort((a, b) => ts(b).compareTo(ts(a)));
        final shown = invites.take(3).toList();
        final extra = invites.length - shown.length;

        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_c.value);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++)
                  FadeSlideIn(
                    key: ValueKey("inv_${shown[i].id}"),
                    delay: Duration(milliseconds: 120 * i),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _tile(context, shown[i], t),
                    ),
                  ),
                if (extra > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationScreen()),
                      ),
                      icon: const Icon(Icons.notifications_active_rounded,
                          size: 18),
                      label: Text("View all ${invites.length} invitations"),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tile(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc, double t) {
    final data = doc.data();
    final accepted = _inviteStatus(data) == "accepted";
    final unread = data["isRead"] != true;
    final sponsor = (data["sponsorName"] ?? "A sponsor").toString();
    final n = (data["scholarshipTitles"] is List)
        ? (data["scholarshipTitles"] as List).length
        : 0;
    final gold = AppColors.secondary;
    final navy = AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          try {
            if (unread) await NotificationService().markRead(doc.id);
          } catch (_) {}
          if (context.mounted) showInviteDialog(context, data);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navy, navy.withOpacity(0.88)],
            ),
            borderRadius: BorderRadius.circular(20),
            border:
            Border.all(color: gold.withOpacity(0.6 + 0.4 * t), width: 2),
            boxShadow: [
              BoxShadow(
                color: gold.withOpacity(0.25 + 0.35 * t),
                blurRadius: 14 + 16 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration:
                    BoxDecoration(shape: BoxShape.circle, color: gold),
                    child: Icon(
                      accepted ? Icons.check_rounded : Icons.mail_rounded,
                      color: navy,
                      size: 26,
                    ),
                  ),
                  if (unread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Opacity(
                        opacity: 0.35 + 0.65 * t,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Opacity(
                      opacity: 0.55 + 0.45 * t,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          accepted
                              ? "ACCEPTED · APPLY NOW"
                              : (unread
                              ? "NEW INVITATION"
                              : "PENDING INVITATION"),
                          style: TextStyle(
                            color: gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      accepted
                          ? "You accepted $sponsor's invitation"
                          : "$sponsor invited you to apply!",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      accepted
                          ? "Choose a scholarship and apply"
                          : "$n matching scholarship${n == 1 ? '' : 's'}"
                          "  •  Tap to view & accept",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  accepted ? "Apply" : "View",
                  style: TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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

// =========================================================
// TOP POPUP BANNER (wrap the student dashboard body with this)
// Slides in from the top for a new invite / visit request / approval
// =========================================================

class InviteBannerHost extends StatefulWidget {
  final Widget child;
  const InviteBannerHost({super.key, required this.child});

  @override
  State<InviteBannerHost> createState() => _InviteBannerHostState();
}

class _InviteBannerHostState extends State<InviteBannerHost> {
  final NotificationService _service = NotificationService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final Set<String> _shown = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pending = [];

  String? _currentId;
  Map<String, dynamic>? _currentData;
  bool _visible = false;
  Timer? _timer;

  StreamSubscription<User?>? _authSub;
  String? _subUid;

  @override
  void initState() {
    super.initState();
    debugPrint("BANNER: host started");
    // authStateChanges emits the current user right away, and again if the
    // user changes - so we never miss the subscription on slow auth restore.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint("BANNER: auth user = ${user?.uid}");
      _subscribe(user?.uid);
    });
  }

  void _subscribe(String? uid) {
    if (uid == _subUid) return;
    _sub?.cancel();
    _subUid = uid;
    if (uid == null) return;

    _sub = _service.streamFor(uid).listen((snap) {
      final list = snap.docs.where((d) {
        final m = d.data();
        return m["isRead"] != true &&
            (m["audience"] ?? "student") == "student" &&
            !_shown.contains(d.id);
      }).toList();

      DateTime ts(QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final t = d.data()["createdAt"];
        return t is Timestamp ? t.toDate() : DateTime.now();
      }

      list.sort((a, b) => ts(b).compareTo(ts(a)));
      debugPrint(
          "BANNER: ${snap.docs.length} notifications, ${list.length} unread to show");
      _pending = list.take(3).toList();
      _showNext();
    }, onError: (e) => debugPrint("BANNER STREAM ERROR: $e"));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _showNext() {
    if (!mounted || _currentId != null || _pending.isEmpty) return;

    final d = _pending.removeAt(0);
    _shown.add(d.id);

    setState(() {
      _currentId = d.id;
      _currentData = d.data();
      _visible = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 12), _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _visible = false);

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _currentId = null;
        _currentData = null;
      });
      _showNext();
    });
  }

  Future<void> _view() async {
    final id = _currentId;
    final data = _currentData;
    if (id == null || data == null) return;

    try {
      await _service.markRead(id);
    } catch (_) {}

    _dismiss();
    if (!mounted) return;

    final type = (data["type"] ?? "").toString();
    if (type == "invite") {
      showInviteDialog(context, data);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyApplicationsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_currentData != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: AnimatedSlide(
                      offset: _visible ? Offset.zero : const Offset(0, -1.5),
                      duration: const Duration(milliseconds: 450),
                      curve: _visible ? Curves.easeOutBack : Curves.easeIn,
                      child: IgnorePointer(
                        ignoring: !_visible,
                        child: AnimatedOpacity(
                          opacity: _visible ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: _banner(_currentData!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _banner(Map<String, dynamic> d) {
    final gold = AppColors.secondary;
    final type = (d["type"] ?? "").toString();
    final isInvite = type == "invite";

    final sponsor = (d["sponsorName"] ?? "A sponsor").toString();
    final titles = (d["scholarshipTitles"] is List)
        ? (d["scholarshipTitles"] as List).map((e) => e.toString()).toList()
        : <String>[];

    final chip = const {
      "invite": "NEW INVITATION",
      "approved": "APPROVED",
      "rejected": "APPLICATION UPDATE",
      "visit_request": "ACTION NEEDED",
      "docs_verified": "VERIFIED",
      "field_verified": "VERIFIED",
      "applied": "SUBMITTED",
      "semester_approved": "SEMESTER APPROVED",
      "semester_rejected": "SEMESTER UPDATE",
    }[type] ??
        "NEW NOTIFICATION";

    final headline = isInvite
        ? "$sponsor invited you to apply!"
        : (d["title"] ?? "Notification").toString();

    final sub = isInvite && titles.isNotEmpty
        ? "You match ${titles.length} scholarship${titles.length == 1 ? '' : 's'}: "
        "${titles.first}${titles.length > 1 ? '  +${titles.length - 1} more' : ''}"
        : (d["body"] ?? "").toString();

    final icon = const {
      "invite": Icons.mail_rounded,
      "approved": Icons.emoji_events_rounded,
      "rejected": Icons.info_rounded,
      "visit_request": Icons.event_available_rounded,
      "docs_verified": Icons.fact_check_rounded,
      "field_verified": Icons.verified_user_rounded,
      "applied": Icons.description_rounded,
      "semester_approved": Icons.check_circle_rounded,
      "semester_rejected": Icons.info_rounded,
    }[type] ??
        Icons.notifications_active_rounded;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.88)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold, width: 2),
          boxShadow: [
            BoxShadow(
              color: gold.withOpacity(0.45),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold,
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        color: gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _view,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: gold,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          isInvite ? "View Invitation" : "View",
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: _dismiss,
                        child: Text(
                          "Later",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: Icon(Icons.close_rounded,
                  color: Colors.white.withOpacity(0.7), size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// NOTIFICATION SCREEN
// =========================================================

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final service = NotificationService();

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Please login again")));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamFor(uid),
        builder: (context, snapshot) {
          final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ];

          // newest first (client-side, no index needed)
          docs.sort((a, b) {
            final ta = a.data()["createdAt"];
            final tb = b.data()["createdAt"];
            final da = ta is Timestamp ? ta.toDate() : DateTime.now();
            final db = tb is Timestamp ? tb.toDate() : DateTime.now();
            return db.compareTo(da);
          });

          final unread = docs.where((d) => d.data()["isRead"] != true).length;

          return SingleChildScrollView(
            child: Column(
              children: [
                _Header(
                  unread: unread,
                  onBack: () => Navigator.pop(context),
                  onMarkAll: unread == 0 ? null : () => service.markAllRead(uid),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _body(context, snapshot, docs, service),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(
      BuildContext context,
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      NotificationService service,
      ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (snapshot.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            "Something went wrong\n${snapshot.error}",
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
        ),
      );
    }

    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded,
                  size: 70, color: AppColors.secondary),
              const SizedBox(height: 16),
              Text(
                "No notifications yet",
                style: AppTextStyles.title.copyWith(
                  fontSize: 19,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Invitations from sponsors and application updates will appear here.",
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < docs.length; i++)
          FadeSlideIn(
            key: ValueKey("fs_${docs[i].id}"),
            delay: Duration(milliseconds: 70 * math.min(i, 8)),
            child: _NotificationCard(
              id: docs[i].id,
              data: docs[i].data(),
              service: service,
            ),
          ),
      ],
    );
  }
}

// =========================================================
// HEADER
// =========================================================

class _Header extends StatelessWidget {
  final int unread;
  final VoidCallback onBack;
  final VoidCallback? onMarkAll;

  const _Header({
    required this.unread,
    required this.onBack,
    required this.onMarkAll,
  });

  Widget _circle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(0.06),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.82)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: -40, top: 50, child: _circle(120)),
          Positioned(right: -30, top: -20, child: _circle(120)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          "Notifications",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title.copyWith(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onMarkAll,
                        child: Text(
                          "Mark all",
                          style: TextStyle(
                            color: onMarkAll == null
                                ? Colors.white38
                                : AppColors.secondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(color: AppColors.secondary, width: 2),
                    ),
                    child: Icon(Icons.notifications_active_rounded,
                        color: AppColors.secondary, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unread == 0
                        ? "You're all caught up"
                        : "$unread unread notification${unread == 1 ? '' : 's'}",
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12.5,
                      color: Colors.white.withOpacity(0.85),
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

// =========================================================
// NOTIFICATION CARD
// =========================================================

class _NotificationCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final NotificationService service;

  const _NotificationCard({
    required this.id,
    required this.data,
    required this.service,
  });

  ({IconData icon, Color color}) get _style {
    switch ((data["type"] ?? "info").toString()) {
      case "invite":
        return (icon: Icons.mail_rounded, color: AppColors.secondary);
      case "invite_accepted":
        return (icon: Icons.how_to_reg_rounded, color: AppColors.success);
      case "invite_applied":
        return (icon: Icons.task_alt_rounded, color: AppColors.success);
      case "invite_declined":
        return (icon: Icons.person_off_rounded, color: AppColors.error);
      case "invite_reminder":
        return (icon: Icons.alarm_rounded, color: AppColors.secondary);
      case "applied":
      case "application_received":
        return (icon: Icons.description_rounded, color: AppColors.primary);
      case "docs_verified":
        return (icon: Icons.fact_check_rounded, color: AppColors.success);
      case "field_verified":
        return (icon: Icons.verified_user_rounded, color: AppColors.success);
      case "visit_request":
        return (icon: Icons.event_available_rounded, color: AppColors.secondary);
      case "approved":
      case "semester_approved":
        return (icon: Icons.check_circle_rounded, color: AppColors.success);
      case "rejected":
      case "semester_rejected":
        return (icon: Icons.cancel_rounded, color: AppColors.error);
      default:
        return (icon: Icons.notifications_rounded, color: AppColors.primary);
    }
  }

  String _timeAgo() {
    final t = data["createdAt"];
    if (t is! Timestamp) return "Just now";
    final diff = DateTime.now().difference(t.toDate());
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    final d = t.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }

  Future<void> _open(BuildContext context) async {
    if (data["isRead"] != true) {
      await service.markRead(id);
    }
    if (!context.mounted) return;

    final type = (data["type"] ?? "info").toString();
    final audience = (data["audience"] ?? "student").toString();

    if (audience == "sponsor" && type.startsWith("invite_")) {
      showSponsorInviteDialog(context, data);
      return;
    }

    if (type == "invite_reminder") {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      final sid = (data["sponsorId"] ?? "").toString();
      try {
        final snap = await FirebaseFirestore.instance
            .collection("notifications")
            .doc(service.inviteDocId(sid, uid))
            .get();
        if (snap.exists && context.mounted) {
          showInviteDialog(context, snap.data()!);
          return;
        }
      } catch (e) {
        debugPrint("REMINDER open error: $e");
      }
    }

    if (audience == "sponsor") {
      // sponsor-side notifications: just show the details
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text((data["title"] ?? "Notification").toString()),
          content: Text((data["body"] ?? "").toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } else if (type == "invite") {
      showInviteDialog(context, data);
    } else {
      // every other student notification -> their applications
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyApplicationsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final unread = data["isRead"] != true;
    final pendingInvite = _isPendingInvite(data);
    final inviteAccepted = _inviteStatus(data) == "accepted";

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => service.delete(id),
      child: _PulseGlow(
        active: _isPendingInvite(data) ||
            (unread &&
                ((data["type"] ?? "") == "invite_accepted" ||
                    (data["type"] ?? "") == "invite_applied")),
        child: Container(
          decoration: BoxDecoration(
            color: pendingInvite ? null : AppColors.card,
            gradient: pendingInvite
                ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF3D1), Colors.white],
            )
                : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: pendingInvite
                  ? AppColors.secondary
                  : (unread
                  ? style.color.withOpacity(0.45)
                  : Colors.transparent),
              width: pendingInvite ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: style.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(style.icon, color: style.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pendingInvite) ...[
                          _BlinkChip(inviteAccepted ? "ACCEPTED · APPLY NOW" : "NEW INVITATION"),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (data["title"] ?? "Notification").toString(),
                                style: AppTextStyles.title.copyWith(
                                  fontSize: 14.5,
                                  color: AppColors.textPrimary,
                                  fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (unread)
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          (data["body"] ?? "").toString(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                        ),
                        if (pendingInvite) ...[
                          const SizedBox(height: 8),
                          Text(
                            inviteAccepted
                                ? "Choose a scholarship & apply  →"
                                : "View sponsor details & accept  →",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          _timeAgo(),
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
            ),
          ),
        ),
      ),
    );
  }
}