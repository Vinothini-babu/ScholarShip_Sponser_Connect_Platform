import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../utils/contact_actions.dart';
import 'ticket_detail_screen.dart';
/// Support & Help screen — FAQ, direct contact options (call / email /
/// WhatsApp), and a simple "raise a ticket" system backed by Firestore
/// (support_tickets collection) so students get a real response trail
/// instead of just a static contact page.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // Real details contact_actions.dart-la (SupportContact) maathunga.
  static const String _supportPhone = SupportContact.phone;
  static const String _supportEmail = SupportContact.email;

  final _subjectC = TextEditingController();
  final _messageC = TextEditingController();
  bool _submitting = false;

  static const List<_Faq> _faqs = [
    _Faq(
      "How do I apply for a scholarship?",
      "Go to Home or Search, open a scholarship you're eligible for, tap "
          "\"Apply Now\", fill in your Statement of Purpose and academic "
          "percentage, then upload the required documents before submitting.",
    ),
    _Faq(
      "Why does a document upload fail?",
      "Only PDF, JPG and PNG files are accepted, and screenshots are "
          "rejected — upload the original file (exported/scanned document), "
          "not a screenshot of it. Also check your internet connection.",
    ),
    _Faq(
      "Why am I marked \"Not eligible\" for a scholarship?",
      "Eligibility is based on your Course, Category, Percentage and Annual "
          "Income in your Profile. Open Profile → Edit Profile and make sure "
          "all of these are filled in correctly, then check again.",
    ),
    _Faq(
      "How do I track my application status?",
      "Go to Applications from the bottom bar. Each application shows "
          "Submitted → Under Review → Approved/Rejected, with the sponsor's "
          "remarks if any.",
    ),
    _Faq(
      "What happens after my scholarship is approved?",
      "You'll be asked to upload your marks at the end of every semester "
          "for renewal. Go to your approved application and tap \"Upload "
          "Next Semester Marks\" when it's due.",
    ),
    _Faq(
      "I forgot my password. What do I do?",
      "Use \"Forgot Password\" on the Login screen — a reset link will be "
          "sent to your registered email.",
    ),
  ];

  @override
  void dispose() {
    _subjectC.dispose();
    _messageC.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final subject = _subjectC.text.trim();
    final message = _messageC.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in both subject and message")),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection("support_tickets").add({
        "studentId": user.uid,
        "studentName": userData["name"] ?? user.displayName ?? "Student",
        "studentEmail": userData["email"] ?? user.email ?? "",
        "subject": subject,
        "message": message,
        "status": "Open",
        "createdAt": FieldValue.serverTimestamp(),
      });

      _subjectC.clear();
      _messageC.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your ticket has been submitted")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not submit ticket: $e")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.pop(context)),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------------- CONTACT OPTIONS ----------------
                      Text(
                        "Contact Us",
                        style: AppTextStyles.title.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 640;
                          final tiles = [
                            _ContactTile(
                              icon: Icons.call_rounded,
                              label: "Call Us",
                              subtitle: _supportPhone,
                              color: AppColors.success,
                              onTap: () => showContactSheet(context, ContactType.call),
                            ),
                            _ContactTile(
                              icon: Icons.chat_rounded,
                              label: "WhatsApp",
                              subtitle: "Chat with support",
                              color: const Color(0xFF25D366),
                              onTap: () =>
                                  showContactSheet(context, ContactType.whatsapp),
                            ),
                            _ContactTile(
                              icon: Icons.email_rounded,
                              label: "Email",
                              subtitle: _supportEmail,
                              color: AppColors.primary,
                              onTap: () => showContactSheet(context, ContactType.email),
                            ),
                          ];

                          if (wide) {
                            return Row(
                              children: [
                                for (int i = 0; i < tiles.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(child: tiles[i]),
                                ],
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (int i = 0; i < tiles.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                tiles[i],
                              ],
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // ---------------- FAQ ----------------
                      Text(
                        "Frequently Asked Questions",
                        style: AppTextStyles.title.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < _faqs.length; i++) ...[
                              _FaqTile(faq: _faqs[i]),
                              if (i != _faqs.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 18,
                                  endIndent: 18,
                                  color: AppColors.textSecondary
                                      .withOpacity(0.10),
                                ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ---------------- RAISE A TICKET ----------------
                      Text(
                        "Still need help? Raise a ticket",
                        style: AppTextStyles.title.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Our team will reply here. Tap a ticket below to view replies.",
                        style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _subjectC,
                              decoration: InputDecoration(
                                labelText: "Subject",
                                prefixIcon: const Icon(Icons.short_text_rounded),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _messageC,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: "Describe your issue",
                                alignLabelWithHint: true,
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 60),
                                  child: Icon(Icons.message_rounded),
                                ),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submitting ? null : _submitTicket,
                                icon: _submitting
                                    ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Icon(Icons.send_rounded, size: 18),
                                label: Text(
                                  _submitting ? "Submitting..." : "Submit Ticket",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ---------------- MY TICKETS ----------------
                      if (uid != null) ...[
                        const SizedBox(height: 30),
                        Text(
                          "Your Tickets",
                          style: AppTextStyles.title.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection("support_tickets")
                              .where("studentId", isEqualTo: uid)
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            }

                            if (snap.hasError) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  "Could not load tickets: ${snap.error}",
                                  style: AppTextStyles.subtitle,
                                ),
                              );
                            }

                            // newest first (sorted here so no Firestore
                            // composite index is needed)
                            final docs = [...(snap.data?.docs ?? [])];
                            int ms(dynamic v) =>
                                v is Timestamp ? v.millisecondsSinceEpoch : 1 << 62;
                            docs.sort((a, b) => ms(b.data()["createdAt"])
                                .compareTo(ms(a.data()["createdAt"])));

                            if (docs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  "You haven't raised any tickets yet.",
                                  style: AppTextStyles.subtitle,
                                ),
                              );
                            }

                            return Column(
                              children: [
                                for (final doc in docs)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TicketDetailScreen(
                                                ticketId: doc.id),
                                          ),
                                        ),
                                        child: _TicketTile(data: doc.data()),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// HEADER
// =========================================================

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.80),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: -50, top: 70, child: _circle(150)),
          Positioned(right: -35, top: -25, child: _circle(140)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Support",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title.copyWith(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10),
                      border: Border.all(color: AppColors.secondary, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.headset_mic_rounded,
                      color: AppColors.secondary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "How can we help you today?",
                    style: AppTextStyles.title.copyWith(
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Reach our team or find quick answers below",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
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
// CONTACT TILE
// =========================================================

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                    ),
                  ],
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
// FAQ
// =========================================================

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.faq.question,
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState:
              _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.faq.answer,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// TICKET TILE
// =========================================================

class _TicketTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TicketTile({required this.data});

  Color _statusColor(String status) {
    switch (status) {
      case "Resolved":
        return AppColors.success;
      case "In Progress":
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _date(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final status = (data["status"] ?? "Open").toString();
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data["subject"] ?? "").toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (data["message"] ?? "").toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _date(data["createdAt"]),
                  style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: AppTextStyles.subtitle.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}