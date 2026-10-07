// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/feedback_service.dart';

const Color _navy = Color(0xFF1E3358);
const Color _gold = Color(0xFFE0A93A);

// Sponsors don't give star ratings - they report issues / share suggestions
const List<String> _sponsorCategories = [
  "Report an issue",
  "Suggestion",
  "Application review",
  "Scholarship management",
  "Other",
];

String _ratingLabel(int r) {
  switch (r) {
    case 1:
      return "😞  Poor";
    case 2:
      return "😕  Fair";
    case 3:
      return "🙂  Good";
    case 4:
      return "😊  Very good";
    case 5:
      return "🤩  Excellent";
    default:
      return "Tap a star to rate";
  }
}

String _ago(dynamic ts) {
  if (ts is! Timestamp) return "just now";
  final d = DateTime.now().difference(ts.toDate());
  if (d.inMinutes < 1) return "just now";
  if (d.inMinutes < 60) return "${d.inMinutes}m ago";
  if (d.inHours < 24) return "${d.inHours}h ago";
  if (d.inDays < 30) return "${d.inDays}d ago";
  return "${(d.inDays / 30).floor()}mo ago";
}

// =========================================================
// FEEDBACK SCREEN  (students + sponsors)
// =========================================================

class FeedbackScreen extends StatefulWidget {
  final int initialRating;
  final String source; // general | application_approved | application_rejected
  final String? applicationId;
  final String? scholarshipTitle;
  final bool isSponsor; // sponsor mode: no stars, category + message only

  const FeedbackScreen({
    super.key,
    this.initialRating = 0,
    this.source = "general",
    this.applicationId,
    this.scholarshipTitle,
    this.isSponsor = false,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _msg = TextEditingController();
  final FeedbackService _service = FeedbackService();

  late int _rating = widget.initialRating;
  late String _category = widget.isSponsor
      ? _sponsorCategories.first
      : FeedbackService.categories.first;
  bool _sending = false;
  bool _done = false;
  bool _hoverSubmit = false;
  String? _error;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.isSponsor) {
      if (_msg.text.trim().length < 10) {
        setState(() => _error =
        "Please describe the issue or suggestion (at least 10 characters).");
        return;
      }
    } else if (_rating == 0) {
      setState(() => _error = "Please tap a star to rate your experience.");
      return;
    }
    if (!widget.isSponsor && _rating <= 2 && _msg.text.trim().length < 5) {
      setState(() => _error = "Please tell us briefly what went wrong.");
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await _service.submit(
      rating: _rating,
      category: _category,
      message: _msg.text,
      source: widget.source,
      applicationId: widget.applicationId,
      scholarshipTitle: widget.scholarshipTitle,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = err;
      _done = err == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // header slides down from the top
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, -40 * (1 - v)),
                child: child,
              ),
            ),
            child: _header(context),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 52,
                  ),
                  // top-aligned: card sits right below the header
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, -36 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 450),
                              switchInCurve: Curves.easeOutBack,
                              transitionBuilder: (c, a) => FadeTransition(
                                opacity: a,
                                child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.94, end: 1)
                                        .animate(a),
                                    child: c),
                              ),
                              child: _done
                                  ? _successCard(context)
                                  : _formCard(),
                            ),
                            if (uid != null) ...[
                              const SizedBox(height: 26),
                              _previous(uid),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF3B4F77)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        border: Border(bottom: BorderSide(color: _gold, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // back button - aligned with the card's left edge
                  Align(
                    alignment: Alignment.topLeft,
                    child: _Reveal(
                      delay: const Duration(milliseconds: 100),
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 40, minHeight: 40),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.12),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  // centered title block
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, v, c) =>
                            Transform.scale(scale: v, child: c),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _gold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withOpacity(0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                              widget.isSponsor
                                  ? Icons.lightbulb_outline_rounded
                                  : Icons.rate_review_rounded,
                              size: 28,
                              color: _navy),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Reveal(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                            widget.isSponsor
                                ? "Report an issue / Suggestion"
                                : "Share your feedback",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2)),
                      ),
                      const SizedBox(height: 4),
                      _Reveal(
                        delay: const Duration(milliseconds: 320),
                        child: Text(
                            widget.isSponsor
                                ? "Tell us what's not working or what we can improve"
                                : "Your voice helps us improve the platform",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13.5)),
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

  // ---------- form ----------
  Widget _formCard() {
    return Container(
      key: const ValueKey("form"),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.scholarshipTitle != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_rounded, size: 16, color: _navy),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(widget.scholarshipTitle!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (widget.isSponsor) ...[
            const _Reveal(
              delay: Duration(milliseconds: 150),
              child: Text("What would you like to tell us?",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 22),
          ] else ...[
            const _Reveal(
              delay: const Duration(milliseconds: 150),
              child: Text("How was your experience?",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            _Reveal(
              delay: const Duration(milliseconds: 250),
              child: Center(child: _StarRow(rating: _rating, onChanged: (r) {
                setState(() {
                  _rating = r;
                  _error = null;
                });
              })),
            ),
            const SizedBox(height: 10),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(a),
                    child: c,
                  ),
                ),
                child: Text(
                  _ratingLabel(_rating),
                  key: ValueKey(_rating),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _rating == 0 ? AppColors.textSecondary : _navy,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
          const _Reveal(
            delay: const Duration(milliseconds: 350),
            child: Text("WHAT IS IT ABOUT?",
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: _gold)),
          ),
          const SizedBox(height: 10),
          _Reveal(
            delay: const Duration(milliseconds: 420),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in (widget.isSponsor
                    ? _sponsorCategories
                    : FeedbackService.categories))
                  GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _category == c ? _navy : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _category == c
                                  ? _navy
                                  : Colors.black.withOpacity(0.1)),
                        ),
                        child: Text(c,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color:
                              _category == c ? Colors.white : _navy,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            widget.isSponsor
                ? "DESCRIBE THE ISSUE OR SUGGESTION"
                : (_rating > 0 && _rating <= 2
                ? "TELL US WHAT WENT WRONG"
                : "ANYTHING YOU'D LIKE TO ADD? (OPTIONAL)"),
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: _gold),
          ),
          const SizedBox(height: 10),
          _Reveal(
            delay: const Duration(milliseconds: 520),
            child: TextField(
              controller: _msg,
              minLines: 4,
              maxLines: 7,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: widget.isSponsor
                    ? "Explain what happened or what you'd like us to add..."
                    : "Write your comments here...",
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _error == null
                ? const SizedBox(width: double.infinity, height: 0)
                : Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(_error!,
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          _Reveal(
            delay: const Duration(milliseconds: 620),
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoverSubmit = true),
              onExit: (_) => setState(() => _hoverSubmit = false),
              child: AnimatedScale(
                scale: _hoverSubmit && !_sending ? 1.015 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(widget.isSponsor ? "Submit Report" : "Submit Feedback",
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: _gold,
                      foregroundColor: _navy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- success ----------
  Widget _successCard(BuildContext context) {
    return Container(
      key: const ValueKey("done"),
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: _cardDeco(),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (context, v, c) => Transform.scale(scale: v, child: c),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  size: 52, color: AppColors.success),
            ),
          ),
          const SizedBox(height: 18),
          const Text("Thank you!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            widget.isSponsor
                ? "Your report has been sent to the admin team.\n"
                "If we reply, you'll get a notification."
                : "Your feedback has been sent to the admin team.\n"
                "If we reply, you'll get a notification.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _done = false;
                  _rating = 0;
                  _msg.clear();
                }),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Send another"),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => Navigator.maybePop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Done"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- my previous feedback (live) ----------
  Widget _previous(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.streamMine(uid),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? []).toList()
          ..sort((a, b) {
            final x = a.data()["createdAt"];
            final y = b.data()["createdAt"];
            if (x is Timestamp && y is Timestamp) return y.compareTo(x);
            return 0;
          });
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Reveal(
              delay: Duration(milliseconds: 700),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("MY PREVIOUS FEEDBACK",
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: _gold)),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < docs.length; i++)
              _Reveal(
                key: ValueKey("pf_${docs[i].id}"),
                delay: Duration(milliseconds: 750 + 70 * math.min(i, 6)),
                child: _previousTile(docs[i].data()),
              ),
          ],
        );
      },
    );
  }

  Widget _previousTile(Map<String, dynamic> m) {
    final rating = (m["rating"] is num) ? (m["rating"] as num).toInt() : 0;
    final reply = (m["adminReply"] ?? "").toString();
    final reviewed = (m["status"] ?? "new") == "reviewed";
    final msg = (m["message"] ?? "").toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (rating > 0) ...[
                _MiniStars(rating),
                const SizedBox(width: 10),
              ],
              Text((m["category"] ?? "").toString(),
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (reviewed ? AppColors.success : _gold)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reviewed ? "REVIEWED" : "SENT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: reviewed ? AppColors.success : _gold,
                  ),
                ),
              ),
            ],
          ),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(msg, style: const TextStyle(fontSize: 13.5, height: 1.45)),
          ],
          const SizedBox(height: 8),
          Text(_ago(m["createdAt"]),
              style:
              TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _navy.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: _gold, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Admin reply",
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _navy)),
                  const SizedBox(height: 4),
                  Text(reply,
                      style: const TextStyle(fontSize: 13, height: 1.45)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.black.withOpacity(0.05)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

// =========================================================
// interactive 5-star row
// =========================================================

class _StarRow extends StatefulWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  const _StarRow({required this.rating, required this.onChanged});

  @override
  State<_StarRow> createState() => _StarRowState();
}

class _StarRowState extends State<_StarRow> {
  int _hover = 0;

  @override
  Widget build(BuildContext context) {
    final shown = _hover > 0 ? _hover : widget.rating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = i),
            onExit: (_) => setState(() => _hover = 0),
            child: GestureDetector(
              onTap: () => widget.onChanged(i),
              child: _Reveal(
                delay: Duration(milliseconds: 60 * i),
                child: AnimatedScale(
                  scale: i <= shown ? 1.15 : 0.95,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      i <= shown
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 46,
                      color: i <= shown
                          ? _gold
                          : AppColors.textSecondary.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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

// =========================================================
// DASHBOARD PROMPT  ("How was your experience?" after a decision)
//
// Student dashboard:  const FeedbackPromptCard()
// Sponsor dashboard:  const FeedbackPromptCard(isSponsor: true)
// Shows for an Approved / Rejected application that has no feedback yet.
// =========================================================

class FeedbackPromptCard extends StatefulWidget {
  final bool isSponsor;
  final EdgeInsets padding;
  const FeedbackPromptCard({
    super.key,
    this.isSponsor = false,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 22),
  });

  // "Maybe later" hides a card until the app restarts
  static final Set<String> _dismissed = {};

  @override
  State<FeedbackPromptCard> createState() => _FeedbackPromptCardState();
}

class _FeedbackPromptCardState extends State<FeedbackPromptCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

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
      stream: FirebaseFirestore.instance
          .collection("applications")
          .where(widget.isSponsor ? "sponsorId" : "studentId",
          isEqualTo: uid)
          .snapshots(),
      builder: (context, appSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FeedbackService().streamMine(uid),
          builder: (context, fbSnap) {
            final given = <String>{
              for (final d in fbSnap.data?.docs ?? [])
                (d.data()["applicationId"] ?? "").toString()
            };

            final candidates = (appSnap.data?.docs ?? []).where((d) {
              final s = (d.data()["status"] ?? "").toString().toLowerCase();
              return (s == "approved" || s == "rejected") &&
                  !given.contains(d.id) &&
                  !FeedbackPromptCard._dismissed.contains(d.id);
            }).toList();

            if (candidates.isEmpty) return const SizedBox.shrink();

            final doc = candidates.first;
            final m = doc.data();
            final approved =
                (m["status"] ?? "").toString().toLowerCase() == "approved";
            final title = (m["scholarshipTitle"] ?? "the scholarship").toString();
            final whoRaw = (m["studentName"] ?? "").toString().trim();
            final who = whoRaw.isEmpty ? "this student" : whoRaw;

            const white = TextStyle(color: Colors.white, height: 1.4);
            const hl = TextStyle(
                color: _gold, fontWeight: FontWeight.w900); // highlight

            final headline = widget.isSponsor
                ? Text.rich(
              TextSpan(
                style: white.copyWith(
                    fontSize: 17, fontWeight: FontWeight.w800),
                children: [
                  const TextSpan(text: "Any issue or suggestion about "),
                  TextSpan(text: who, style: hl),
                  const TextSpan(text: "'s application?"),
                ],
              ),
              textAlign: TextAlign.center,
            )
                : Text(
              approved
                  ? "Congratulations! 🎉 How was your experience?"
                  : "Help us improve — rate your experience",
              textAlign: TextAlign.center,
              style: white.copyWith(
                  fontSize: 17, fontWeight: FontWeight.w800),
            );

            final sub = Text.rich(
              TextSpan(
                style: white.copyWith(
                    fontSize: 13, color: Colors.white.withOpacity(0.85)),
                children: widget.isSponsor
                    ? [
                  TextSpan(
                      text:
                      "You ${approved ? 'approved' : 'rejected'} the application for "),
                  TextSpan(text: title, style: hl),
                ]
                    : [
                  const TextSpan(text: "Your application for "),
                  TextSpan(text: title, style: hl),
                  TextSpan(
                      text: approved
                          ? " was approved."
                          : " was not approved this time."),
                ],
              ),
              textAlign: TextAlign.center,
            );

            return Padding(
              padding: widget.padding,
              child: _Reveal(
                key: ValueKey("fp_${doc.id}"),
                child: Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: approved
                          ? [const Color(0xFF1E3358), const Color(0xFF2E7D5B)]
                          : [const Color(0xFF1E3358), const Color(0xFF3B4F77)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withOpacity(0.7), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withOpacity(0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.elasticOut,
                            builder: (context, v, c) =>
                                Transform.scale(scale: v, child: c),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _gold,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _gold.withOpacity(0.45),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.isSponsor
                                    ? Icons.lightbulb_outline_rounded
                                    : Icons.rate_review_rounded,
                                color: _navy,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          headline,
                          const SizedBox(height: 6),
                          sub,
                          const SizedBox(height: 18),
                          if (widget.isSponsor)
                            ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FeedbackScreen(
                                    isSponsor: true,
                                    applicationId: doc.id,
                                    scholarshipTitle: title,
                                    source: approved
                                        ? "application_approved"
                                        : "application_rejected",
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.lightbulb_outline_rounded,
                                  size: 18),
                              label: const Text("Report / Suggest",
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                // explicit size: app theme may force a full-width button
                                minimumSize: const Size(0, 46),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                backgroundColor: _gold,
                                foregroundColor: _navy,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24)),
                              ),
                            )
                          else
                            AnimatedBuilder(
                              animation: _c,
                              builder: (context, _) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 1; i <= 5; i++)
                                    _promptStar(
                                        context, i, doc.id, title, approved),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => setState(() =>
                                FeedbackPromptCard._dismissed.add(doc.id)),
                            child: Text("Maybe later",
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _promptStar(BuildContext context, int i, String appId, String title,
      bool approved) {
    // gentle wave across the stars
    final s = 1 + 0.12 * math.sin(2 * math.pi * (_c.value - i * 0.1));
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackScreen(
            initialRating: i,
            applicationId: appId,
            scholarshipTitle: title,
            source: approved ? "application_approved" : "application_rejected",
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: s,
            child: const Icon(Icons.star_rounded, size: 34, color: _gold),
          ),
        ),
      ),
    );
  }
}