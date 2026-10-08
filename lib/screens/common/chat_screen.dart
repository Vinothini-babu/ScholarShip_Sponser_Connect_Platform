import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/chat_service.dart';

/// Student <-> Sponsor chat for one application.
/// Place this file in lib/screens/common/chat_screen.dart
class ChatScreen extends StatefulWidget {
  final String applicationId;
  final String myRole; // "student" | "sponsor"
  final String otherName; // name shown in the header
  final String scholarshipTitle;

  const ChatScreen({
    super.key,
    required this.applicationId,
    required this.myRole,
    required this.otherName,
    required this.scholarshipTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chat = ChatService();
  final TextEditingController _controller = TextEditingController();

  late String _role;
  bool _sending = false;
  String? _lastSyncedId;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? "";

  List<String> get _quickReplies => _role == "sponsor"
      ? const [
    "Please re-upload a clearer copy of your marksheet.",
    "One of your documents is missing. Please upload it.",
    "Your application is under review.",
  ]
      : const [
    "Thank you!",
    "I have re-uploaded the document.",
    "Could you please clarify?",
  ];

  @override
  void initState() {
    super.initState();
    _role = widget.myRole;
    // decide the real role from the logged-in user (safety net)
    _chat.roleFor(widget.applicationId, widget.myRole).then((r) {
      if (mounted && r != _role) setState(() => _role = r);
    });
    _messagesStream = _chat.messages(widget.applicationId);
    _chat.markRead(widget.applicationId, _role);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, "0");
    return "$h:$m ${d.hour >= 12 ? "PM" : "AM"}";
  }

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return "Today";
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return "Yesterday";
    return "${d.day.toString().padLeft(2, "0")}/"
        "${d.month.toString().padLeft(2, "0")}/${d.year}";
  }

  /// A new message from the other person arrived while this screen is open.
  void _syncRead(String newestId, Map<String, dynamic> newest) {
    if ((newest["senderRole"] ?? "") == _role) return;
    if (_lastSyncedId == newestId) return;
    _lastSyncedId = newestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chat.markRead(widget.applicationId, _role);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    final error = await _chat.send(
      applicationId: widget.applicationId,
      myRole: _role,
      text: text,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (error != null) {
      _controller.text = text; // give the text back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  void _useQuickReply(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  Widget _centered(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: child,
    ),
  );

  // ------------------------------------------------------------
  // build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _centered(_buildMessages())),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final rawName = widget.otherName.trim();
    final name = rawName.isEmpty
        ? (_role == "sponsor" ? "Student" : "Sponsor")
        : rawName;
    final initial = name.isEmpty ? "?" : name[0].toUpperCase();

    // Floating header card: gap above (so it sits lower on the screen)
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      margin: EdgeInsets.fromLTRB(16, topInset + 44, 16, 0),
      padding: const EdgeInsets.fromLTRB(8, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.secondary,
            child: Text(
              initial,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.scholarshipTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDCE6F8),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Unable to load messages.\n\n${snap.error}",
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle.copyWith(color: AppColors.error),
              ),
            ),
          );
        }

        if (!snap.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                Text(
                  "Loading messages…",
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        _syncRead(docs.first.id, docs.first.data());

        return ListView.builder(
          reverse: true, // newest at the bottom
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final m = docs[i].data();
            final mine = (m["senderId"] ?? "") == _uid;

            final ts = m["createdAt"];
            final when = ts is Timestamp ? ts.toDate() : DateTime.now();

            // date separator above the first message of each day
            bool showDate = i == docs.length - 1;
            if (!showDate) {
              final older = docs[i + 1].data()["createdAt"];
              if (older is Timestamp) {
                showDate = !_sameDay(older.toDate(), when);
              }
            }

            return Column(
              children: [
                if (showDate) _dateChip(_dayLabel(when)),
                _bubble(m, mine, when),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dateChip(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m, bool mine, DateTime when) {
    final text = (m["text"] ?? "").toString();
    final screenW = MediaQuery.of(context).size.width;
    final maxW = screenW * 0.78 > 520 ? 520.0 : screenW * 0.78;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          gradient: mine
              ? LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.88),
            ],
          )
              : null,
          color: mine ? null : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: mine
              ? null
              : Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                text,
                style: TextStyle(
                  color: mine ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _time(when),
              style: TextStyle(
                fontSize: 10.5,
                color: mine ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final sponsor = _role == "sponsor";
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No messages yet",
              style: AppTextStyles.title.copyWith(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sponsor
                  ? "Ask the student a question about this application, "
                  "for example about an unclear document."
                  : "Have a doubt about this application? "
                  "Send a message to the sponsor.",
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final canSend = _controller.text.trim().isNotEmpty && !_sending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _centered(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // quick replies
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickReplies.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ActionChip(
                      label: Text(
                        _quickReplies[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AppColors.secondary.withOpacity(0.14),
                      side: BorderSide.none,
                      onPressed: () => _useQuickReply(_quickReplies[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      // Enter = send, Shift+Enter = new line (desktop)
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.enter):
                          _send,
                        },
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 1000,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Type a message…",
                            counterText: "",
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: canSend ? _send : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: canSend
                              ? AppColors.secondary
                              : AppColors.secondary.withOpacity(0.35),
                        ),
                        child: _sending
                            ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                            : Icon(
                          Icons.send_rounded,
                          color: AppColors.primary,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================
// ChatEntryButton
//
// Drop this anywhere (sponsor application details, student application
// screen). It shows an unread badge and opens the ChatScreen.
// ==============================================================
class ChatEntryButton extends StatelessWidget {
  final String applicationId;
  final String myRole; // "student" | "sponsor"
  final String otherName;
  final String scholarshipTitle;

  const ChatEntryButton({
    super.key,
    required this.applicationId,
    required this.myRole,
    required this.otherName,
    required this.scholarshipTitle,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("applications")
          .doc(applicationId)
          .snapshots(),
      builder: (context, snap) {
        final app = snap.data?.data();
        // role comes from the logged-in user, not from the caller
        final role = ChatService.roleOf(app, uid, myRole);
        final unread = app == null ? 0 : ChatService.unreadCount(app, role);
        final label =
        role == "sponsor" ? "Message Student" : "Message Sponsor";

        return SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    applicationId: applicationId,
                    myRole: role,
                    // if the caller passed the wrong role, its name is wrong too
                    otherName: role == myRole ? otherName : "",
                    scholarshipTitle: scholarshipTitle,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.secondary, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unread > 99 ? "99+" : "$unread new",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}