// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/feedback_service.dart';

const Color _navy = Color(0xFF1E3358);
const Color _gold = Color(0xFFE0A93A);
const Color _studentColor = Colors.indigo;
const Color _sponsorColor = Colors.pink;

String _ago(dynamic ts) {
  if (ts is! Timestamp) return "just now";
  final d = DateTime.now().difference(ts.toDate());
  if (d.inMinutes < 1) return "just now";
  if (d.inMinutes < 60) return "${d.inMinutes}m ago";
  if (d.inHours < 24) return "${d.inHours}h ago";
  if (d.inDays < 30) return "${d.inDays}d ago";
  return "${(d.inDays / 30).floor()}mo ago";
}

class _Fb {
  final String id;
  final Map<String, dynamic> m;
  _Fb(this.id, this.m);

  String get userId => (m["userId"] ?? "").toString();
  String get role => (m["role"] ?? "student").toString();
  bool get isSponsor => role == "sponsor";
  String get name => (m["name"] ?? "Anonymous").toString();
  int get rating => (m["rating"] is num) ? (m["rating"] as num).toInt() : 0;
  String get category => (m["category"] ?? "").toString();
  String get message => (m["message"] ?? "").toString();
  String get source => (m["source"] ?? "general").toString();
  String get scholarship => (m["scholarshipTitle"] ?? "").toString();
  bool get isNew => (m["status"] ?? "new") == "new";
  String get reply => (m["adminReply"] ?? "").toString();
  dynamic get createdAt => m["createdAt"];
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : "?";
  Color get color => isSponsor ? _sponsorColor : _studentColor;

  String get contextText {
    if (source == "application_approved") {
      return "After an approved application${scholarship.isEmpty ? '' : ' • $scholarship'}";
    }
    if (source == "application_rejected") {
      return "After a rejected application${scholarship.isEmpty ? '' : ' • $scholarship'}";
    }
    return "";
  }
}

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final FeedbackService _service = FeedbackService();
  final TextEditingController _search = TextEditingController();
  String _q = "";
  String _filter = "All"; // All | Students | Sponsors | New | Reviewed | Low

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
  _service.streamAll();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          final all = (snap.data?.docs ?? [])
              .map((d) => _Fb(d.id, d.data()))
              .toList()
            ..sort((a, b) {
              final x = a.createdAt;
              final y = b.createdAt;
              if (x is Timestamp && y is Timestamp) return y.compareTo(x);
              return 0;
            });

          final total = all.length;
          final newCount = all.where((f) => f.isNew).length;
          final avg = total == 0
              ? 0.0
              : all.fold<int>(0, (s, f) => s + f.rating) / total;
          final dist = List<int>.generate(
              5, (i) => all.where((f) => f.rating == 5 - i).length);

          final q = _q.trim().toLowerCase();
          final list = all.where((f) {
            switch (_filter) {
              case "Students":
                if (f.isSponsor) return false;
                break;
              case "Sponsors":
                if (!f.isSponsor) return false;
                break;
              case "New":
                if (!f.isNew) return false;
                break;
              case "Reviewed":
                if (f.isNew) return false;
                break;
              case "Low":
                if (f.rating > 2) return false;
                break;
            }
            if (q.isEmpty) return true;
            return f.name.toLowerCase().contains(q) ||
                f.message.toLowerCase().contains(q) ||
                f.category.toLowerCase().contains(q) ||
                f.scholarship.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              _header(context, total, newCount, avg),
              Expanded(
                child: snap.hasError
                    ? const Center(child: Text("Could not load feedback"))
                    : !snap.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (total > 0) ...[
                            _distribution(dist, total, avg),
                            const SizedBox(height: 18),
                          ],
                          _searchBox(),
                          const SizedBox(height: 12),
                          _chips(all, newCount),
                          const SizedBox(height: 16),
                          if (list.isEmpty)
                            _empty(total == 0)
                          else
                            for (var i = 0; i < list.length; i++)
                              _Reveal(
                                key: ValueKey("fb_${list[i].id}"),
                                delay: Duration(
                                    milliseconds: 45 * math.min(i, 8)),
                                child: _FeedbackCard(
                                  fb: list[i],
                                  onOpen: () => _openDetail(list[i]),
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
        },
      ),
    );
  }

  // ---------- header with live summary ----------
  Widget _header(BuildContext context, int total, int newCount, double avg) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF3B4F77)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: const Border(bottom: BorderSide(color: _gold, width: 3)),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, v, c) =>
                            Transform.scale(scale: v, child: c),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                              color: _gold, shape: BoxShape.circle),
                          child: const Icon(Icons.reviews_rounded, color: _navy),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Feedback & Ratings",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            _LivePill(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          icon: Icons.star_rounded,
                          label: "Average rating",
                          value: avg,
                          decimals: 1,
                          suffix: " / 5",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          icon: Icons.forum_rounded,
                          label: "Total feedback",
                          value: total.toDouble(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          icon: Icons.fiber_new_rounded,
                          label: "Needs review",
                          value: newCount.toDouble(),
                          highlight: newCount > 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- 5..1 star distribution ----------
  Widget _distribution(List<int> dist, int total, double avg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: avg),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  v.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w900, color: _navy),
                ),
              ),
              _MiniStars(avg.round()),
              const SizedBox(height: 4),
              Text("$total reviews",
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text("${5 - i}★",
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                  begin: 0,
                                  end: total == 0 ? 0 : dist[i] / total),
                              duration:
                              Duration(milliseconds: 700 + i * 120),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) =>
                                  LinearProgressIndicator(
                                    value: v,
                                    minHeight: 9,
                                    backgroundColor:
                                    Colors.black.withOpacity(0.06),
                                    valueColor: AlwaysStoppedAnimation(
                                      i < 2
                                          ? AppColors.success
                                          : (i == 2 ? _gold : AppColors.error),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text("${dist[i]}",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: TextField(
      controller: _search,
      onChanged: (v) => setState(() => _q = v),
      decoration: InputDecoration(
        hintText: "Search by name, comment, category or scholarship",
        prefixIcon: const Icon(Icons.search_rounded, color: _navy),
        suffixIcon: _q.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() {
            _search.clear();
            _q = "";
          }),
        ),
        border: InputBorder.none,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );

  Widget _chips(List<_Fb> all, int newCount) {
    final items = <(String, int)>[
      ("All", all.length),
      ("Students", all.where((f) => !f.isSponsor).length),
      ("Sponsors", all.where((f) => f.isSponsor).length),
      ("New", newCount),
      ("Reviewed", all.length - newCount),
      ("Low", all.where((f) => f.rating <= 2).length),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          GestureDetector(
            onTap: () => setState(() => _filter = it.$1),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _filter == it.$1 ? _navy : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: _filter == it.$1
                          ? _navy
                          : Colors.black.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      it.$1 == "Low" ? "Low ratings" : it.$1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _filter == it.$1 ? Colors.white : _navy,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: _filter == it.$1
                            ? Colors.white.withOpacity(0.22)
                            : _gold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("${it.$2}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _filter == it.$1 ? Colors.white : _navy,
                          )),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty(bool none) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50),
    child: Center(
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: _navy.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.rate_review_outlined,
                size: 38, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(none ? "No feedback yet" : "No matching feedback",
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            none
                ? "Ratings and comments from students and sponsors appear here live."
                : "Try a different search or filter.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.black.withOpacity(0.05)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );

  // ---------- detail + reply ----------
  void _openDetail(_Fb fb) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Feedback",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Material(
                  color: AppColors.background,
                  child: _FeedbackDetail(
                    fbId: fb.id,
                    service: _service,
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
            parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

// =========================================================
// list card
// =========================================================

class _FeedbackCard extends StatefulWidget {
  final _Fb fb;
  final VoidCallback onOpen;
  const _FeedbackCard({required this.fb, required this.onOpen});

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.fb;
    final c = f.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: f.isNew
                  ? _gold.withOpacity(0.7)
                  : (_hover ? c.withOpacity(0.5) : Colors.black.withOpacity(0.05)),
              width: f.isNew ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
              color: _hover ? c.withOpacity(0.18) : Colors.black.withOpacity(0.05),
              blurRadius: _hover ? 22 : 10,
              offset: Offset(0, _hover ? 10 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(initial: f.initial, color: c),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 8),
                            _Tag(f.isSponsor ? "SPONSOR" : "STUDENT", c),
                            if (f.isNew) ...[
                              const SizedBox(width: 6),
                              const _Tag("NEW", _gold),
                            ],
                            if (f.reply.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _Tag("REPLIED", AppColors.success),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _MiniStars(f.rating),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                "${f.category}  •  ${_ago(f.createdAt)}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        if (f.message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(f.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// detail dialog (live) with reply + mark reviewed
// =========================================================

class _FeedbackDetail extends StatefulWidget {
  final String fbId;
  final FeedbackService service;
  final BuildContext dialogContext;
  const _FeedbackDetail({
    required this.fbId,
    required this.service,
    required this.dialogContext,
  });

  @override
  State<_FeedbackDetail> createState() => _FeedbackDetailState();
}

class _FeedbackDetailState extends State<_FeedbackDetail> {
  final TextEditingController _reply = TextEditingController();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream =
  FirebaseFirestore.instance
      .collection("feedback")
      .doc(widget.fbId)
      .snapshots();

  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send(_Fb f) async {
    final text = _reply.text.trim();
    if (text.length < 2) {
      setState(() {
        _ok = false;
        _msg = "Write a reply first.";
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = await widget.service
        .reply(id: f.id, userId: f.userId, role: f.role, text: text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = err == null;
      _msg = err ?? "Reply sent. The user has been notified ✅";
      if (err == null) _reply.clear();
    });
  }

  Future<void> _toggle(_Fb f) async {
    setState(() => _busy = true);
    try {
      await widget.service.setReviewed(f.id, f.isNew);
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final f = _Fb(widget.fbId, data);
        final c = f.color;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(c, Colors.black, 0.45)!, c],
                ),
              ),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.elasticOut,
                    builder: (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: Text(f.initial,
                          style: TextStyle(
                              color: c,
                              fontSize: 26,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                            "${f.isSponsor ? 'Sponsor' : 'Student'}  •  ${_ago(f.createdAt)}",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(widget.dialogContext),
                    icon: Icon(Icons.close_rounded,
                        color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _MiniStars(f.rating, size: 26),
                        const SizedBox(width: 12),
                        _Tag(f.category.toUpperCase(), _navy),
                      ],
                    ),
                    if (f.contextText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(f.contextText,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border:
                        Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: SelectableText(
                        f.message.isEmpty ? "(No written comment)" : f.message,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: f.message.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (f.reply.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _navy.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(
                              left: BorderSide(color: _gold, width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Your previous reply",
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _navy)),
                            const SizedBox(height: 4),
                            Text(f.reply,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.45)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text("REPLY TO USER",
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: _gold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reply,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "Write a reply. The user gets a notification.",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.08)),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      child: _msg == null
                          ? const SizedBox(width: double.infinity, height: 0)
                          : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_msg!,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _ok
                                    ? AppColors.success
                                    : AppColors.error)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                    top: BorderSide(color: Colors.black.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _toggle(f),
                    icon: Icon(
                        f.isNew
                            ? Icons.done_all_rounded
                            : Icons.markunread_rounded,
                        size: 17),
                    label: Text(f.isNew ? "Mark reviewed" : "Mark as new"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: _navy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _send(f),
                    icon: _busy
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send_rounded, size: 17),
                    label: const Text("Send reply",
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: _gold,
                      foregroundColor: _navy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// =========================================================
// small widgets
// =========================================================

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final int decimals;
  final String suffix;
  final bool highlight;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.decimals = 0,
    this.suffix = "",
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(highlight ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlight ? _gold : Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: highlight ? _gold : Colors.white, size: 24),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    "${v.toStringAsFixed(decimals)}$suffix",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.3, end: 1).animate(_c),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFF4ADE80), shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        const Text("Live",
            style: TextStyle(color: Colors.white70, fontSize: 12.5)),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final Color color;
  const _Avatar({required this.initial, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.75), Color.lerp(color, Colors.black, 0.35)!],
        ),
      ),
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5)),
    );
  }
}

class _MiniStars extends StatelessWidget {
  final int rating;
  final double size;
  const _MiniStars(this.rating, {this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= rating ? _gold : AppColors.textSecondary.withOpacity(0.5),
          ),
      ],
    );
  }
}

class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _Reveal({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
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
      duration: const Duration(milliseconds: 450),
      child: AnimatedSlide(
        offset: _go ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}