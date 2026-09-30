import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/notification_service.dart';
import 'all_scholarships_screen.dart';
import 'my_applications_screen.dart';

// =========================================================
// BELL (use in the student dashboard header)
// =========================================================

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: NotificationService().unreadCount(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white.withOpacity(0.16),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.notifications_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
  }
}

// =========================================================
// INVITE DIALOG (used by the list and by the popup banner)
// =========================================================

void showInviteDialog(BuildContext context, Map<String, dynamic> data) {
  final titles = (data["scholarshipTitles"] is List)
      ? (data["scholarshipTitles"] as List).map((e) => e.toString()).toList()
      : <String>[];

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text((data["title"] ?? "Invitation").toString()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((data["body"] ?? "").toString()),
            if (titles.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text("Scholarships you match:",
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final t in titles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Close"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AllScholarshipsScreen()),
            );
          },
          child: const Text("Browse Scholarships"),
        ),
      ],
    ),
  );
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
      fit: StackFit.expand,
      children: [
        widget.child,
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
        for (final doc in docs)
          _NotificationCard(
            id: doc.id,
            data: doc.data(),
            service: service,
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unread
                ? style.color.withOpacity(0.45)
                : Colors.transparent,
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
    );
  }
}