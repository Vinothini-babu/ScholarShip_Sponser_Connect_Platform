import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/ticket_model.dart';
import '../../services/ticket_service.dart';

const _statuses = ['Open', 'In Progress', 'Resolved'];

Color _statusColor(String s) {
  switch (s) {
    case 'Open':
      return Colors.orange;
    case 'In Progress':
      return Colors.blue;
    default:
      return Colors.green;
  }
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class AdminSupportTicketsScreen extends StatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  State<AdminSupportTicketsScreen> createState() => _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState extends State<AdminSupportTicketsScreen> {
  final _service = TicketService();
  String _filter = 'All';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Tickets')),
      body: StreamBuilder<List<TicketModel>>(
        stream: _service.streamTickets(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final all = snap.data!;
          int count(String s) => all.where((t) => t.status == s).length;

          final shown = all.where((t) {
            final okStatus = _filter == 'All' || t.status == _filter;
            final q = _search.toLowerCase();
            final okSearch = q.isEmpty ||
                t.subject.toLowerCase().contains(q) ||
                t.studentName.toLowerCase().contains(q);
            return okStatus && okSearch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: _statuses
                      .map((s) => Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(children: [
                          Text('${count(s)}',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _statusColor(s))),
                          Text(s, style: const TextStyle(fontSize: 12)),
                        ]),
                      ),
                    ),
                  ))
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by student or subject',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: ['All', ..._statuses]
                      .map((s) => Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                  ))
                      .toList(),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('No tickets found'))
                    : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final t = shown[i];
                    return ListTile(
                      title: Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${t.studentName} • ${t.category} • ${_fmt(t.createdAt)}'),
                      trailing: Chip(
                        label: Text(t.status,
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                        backgroundColor: _statusColor(t.status),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AdminTicketDetailScreen(ticket: t)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminTicketDetailScreen extends StatefulWidget {
  final TicketModel ticket;
  const AdminTicketDetailScreen({super.key, required this.ticket});

  @override
  State<AdminTicketDetailScreen> createState() => _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState extends State<AdminTicketDetailScreen> {
  final _service = TicketService();
  final _controller = TextEditingController();
  late String _status = widget.ticket.status;
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.addReply(
        ticketId: widget.ticket.id,
        senderRole: 'admin',
        senderId: FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        message: text,
        currentStatus: _status,
      );
      if (_status == 'Open') _status = 'In Progress';
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
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
    final t = widget.ticket;
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket: ${t.subject}', overflow: TextOverflow.ellipsis),
        actions: [
          DropdownButton<String>(
            value: _status,
            underline: const SizedBox(),
            iconEnabledColor: Colors.white,
            dropdownColor: Colors.white,
            selectedItemBuilder: (_) => _statuses
                .map((s) => Center(
              child: Text(s,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ))
                .toList(),
            items: _statuses
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _status = v);
              await _service.updateStatus(t.id, v);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.studentName} • ${t.category} • ${_fmt(t.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 6),
                Text(t.description),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TicketReply>>(
              stream: _service.streamReplies(t.id),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final replies = snap.data!;
                if (replies.isEmpty) return const Center(child: Text('No replies yet'));
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: replies.length,
                  itemBuilder: (_, i) {
                    final r = replies[i];
                    final isAdmin = r.senderRole == 'admin';
                    return Align(
                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.message),
                            const SizedBox(height: 2),
                            Text(_fmt(r.createdAt),
                                style: const TextStyle(fontSize: 10, color: Colors.black45)),
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
                      decoration: const InputDecoration(
                        hintText: 'Type your reply...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
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