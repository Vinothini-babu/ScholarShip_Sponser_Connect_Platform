import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/ticket_model.dart';
import '../../services/ticket_service.dart';

/// Student view of one support ticket: original message, admin replies
/// (live), and a box to reply back.
class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _service = TicketService();
  final _controller = TextEditingController();
  bool _sending = false;

  Color _statusColor(String s) {
    switch (s) {
      case 'Resolved':
        return AppColors.success;
      case 'In Progress':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _send(TicketModel t) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.addReply(
        ticketId: t.id,
        senderRole: 'student',
        senderId: FirebaseAuth.instance.currentUser?.uid ?? '',
        message: text,
        currentStatus: t.status,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TicketModel?>(
      stream: _service.streamTicket(widget.ticketId),
      builder: (context, snap) {
        final t = snap.data;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text('Support Ticket'),
          ),
          body: t == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.subject,
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor(t.status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            t.status,
                            style: TextStyle(
                              color: _statusColor(t.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(t.description,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(_fmt(t.createdAt),
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<TicketReply>>(
                  stream: _service.streamReplies(t.id),
                  builder: (context, rs) {
                    final replies = rs.data ?? [];
                    if (replies.isEmpty) {
                      return Center(
                        child: Text('No replies yet. We will respond soon.',
                            style: AppTextStyles.subtitle),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: replies.length,
                      itemBuilder: (_, i) {
                        final r = replies[i];
                        final mine = r.senderRole == 'student';
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(
                              maxWidth:
                              MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? AppColors.primary.withOpacity(0.15)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  const Text('Support Team',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                Text(r.message),
                                const SizedBox(height: 2),
                                Text(_fmt(r.createdAt),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black45)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Write a reply...',
                            filled: true,
                            fillColor: AppColors.card,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _sending ? null : () => _send(t),
                        icon: _sending
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Icon(Icons.send_rounded, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}