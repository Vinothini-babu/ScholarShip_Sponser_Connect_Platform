import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/application_service.dart'; // adjust path to your project

const _navy = Color(0xFF0B1F4B); // replace with your app's navy constant
const _gold = Color(0xFFD4A017); // replace with your app's gold constant

// =============================================================
// Bottom sheet: student writes the thank-you note
// Returns true if the note was sent.
// =============================================================

Future<bool?> showThankYouSheet(
    BuildContext context, {
      required String applicationId,
      String? sponsorName,
    }) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ThankYouSheet(
      applicationId: applicationId,
      sponsorName: sponsorName,
    ),
  );
}

class _ThankYouSheet extends StatefulWidget {
  final String applicationId;
  final String? sponsorName;
  const _ThankYouSheet({required this.applicationId, this.sponsorName});

  @override
  State<_ThankYouSheet> createState() => _ThankYouSheetState();
}

class _ThankYouSheetState extends State<_ThankYouSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  static const _templates = [
    "Thank you for believing in me. This scholarship means a lot to my family.",
    "Your support will help me complete my studies. I will make you proud.",
    "I am grateful for this opportunity and will work hard to deserve it.",
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final err = await ApplicationService().sendThankYou(
      applicationId: widget.applicationId,
      message: _ctrl.text,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger.showSnackBar(
      const SnackBar(content: Text("Thank-you note sent 💛")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.sponsorName == null || widget.sponsorName!.isEmpty
                  ? "Say thank you 💛"
                  : "Say thank you to ${widget.sponsorName} 💛",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _navy),
            ),
            const SizedBox(height: 4),
            const Text(
              "Your sponsor will see this message. You can send it only once.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _templates
                  .map((t) => ActionChip(
                label: Text(
                  t.length > 34 ? "${t.substring(0, 34)}…" : t,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _gold.withOpacity(0.12),
                side: BorderSide(color: _gold.withOpacity(0.5)),
                onPressed: () => setState(() => _ctrl.text = t),
              ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: "Write your own message...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.favorite, size: 18),
                label: Text(_sending ? "Sending..." : "Send Thank-you"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: _gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// STUDENT side drop-in: nothing until Approved, then the button,
// then "Thank-you sent ✓" with the message once sent.
// =============================================================

class ThankYouButton extends StatelessWidget {
  final String applicationId;
  final String? sponsorName;
  const ThankYouButton({
    super.key,
    required this.applicationId,
    this.sponsorName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .doc(applicationId)
          .snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        if (d == null || d['status'] != 'Approved') {
          return const SizedBox.shrink();
        }

        if (d['thankYouSent'] == true) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Thank-you sent ✓",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _navy)),
                const SizedBox(height: 6),
                Text((d['thankYouMessage'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showThankYouSheet(
                context,
                applicationId: applicationId,
                sponsorName: sponsorName,
              ),
              icon: const Icon(Icons.favorite_border, color: _gold),
              label: const Text("Send Thank-you to Sponsor",
                  style: TextStyle(color: _navy)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _gold),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================
// SPONSOR side drop-in: shows the student's thank-you note
// once it exists (put in application_details_screen.dart).
// =============================================================

class SponsorThankYouCard extends StatelessWidget {
  final String applicationId;
  const SponsorThankYouCard({super.key, required this.applicationId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .doc(applicationId)
          .snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        if (d == null || d['thankYouSent'] != true) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E1), Color(0xFFFFF1C1)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withOpacity(0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.favorite, color: _gold, size: 18),
                SizedBox(width: 8),
                Text("Thank-you from your student",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _navy)),
              ]),
              const SizedBox(height: 8),
              Text((d['thankYouMessage'] ?? '').toString(),
                  style: const TextStyle(fontSize: 14, height: 1.4)),
            ],
          ),
        );
      },
    );
  }
}