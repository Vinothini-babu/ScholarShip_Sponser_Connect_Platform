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
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
          [...(snapshot.data?.docs ?? [])];

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
      case "approved":
        return (icon: Icons.check_circle_rounded, color: AppColors.success);
      case "rejected":
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

    if (type == "invite") {
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
    } else if (type == "approved" || type == "rejected") {
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