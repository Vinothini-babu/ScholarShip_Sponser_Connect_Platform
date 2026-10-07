import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';

class TicketService {
  final _tickets = FirebaseFirestore.instance.collection('support_tickets');

  // All tickets, newest first. Filter by status on the UI side
  // (avoids needing a Firestore composite index).
  Stream<List<TicketModel>> streamTickets() {
    return _tickets
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TicketModel.fromDoc).toList());
  }

  Stream<TicketModel?> streamTicket(String id) => _tickets
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? TicketModel.fromDoc(d) : null);

  Stream<List<TicketReply>> streamReplies(String ticketId) {
    return _tickets
        .doc(ticketId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(TicketReply.fromDoc).toList());
  }

  // Student side: raise a ticket
  Future<void> createTicket(TicketModel t) => _tickets.add(t.toMap());

  Future<void> addReply({
    required String ticketId,
    required String senderRole,
    required String senderId,
    required String message,
    required String currentStatus,
  }) async {
    final ref = _tickets.doc(ticketId);
    await ref.collection('replies').add({
      'senderRole': senderRole,
      'senderId': senderId,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // First admin reply moves Open -> In Progress automatically
    var newStatus = currentStatus;
    if (senderRole == 'admin' && currentStatus == 'Open') newStatus = 'In Progress';
    // Student replies on a resolved ticket reopen it
    if (senderRole == 'student' && currentStatus == 'Resolved') newStatus = 'Open';
    await ref.update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (senderRole == 'admin') {
      await _notifyStudent(
        ticketId: ticketId,
        title: 'Support replied to your ticket',
        body: message,
      );
    }
  }

  // Bell notification for the student (same shape as other student notifications)
  Future<void> _notifyStudent({
    required String ticketId,
    required String title,
    required String body,
  }) async {
    try {
      final snap = await _tickets.doc(ticketId).get();
      final d = snap.data();
      if (d == null) return;
      final studentId = (d['studentId'] ?? '').toString();
      if (studentId.isEmpty) return;
      final subject = (d['subject'] ?? '').toString();
      await FirebaseFirestore.instance.collection('notifications').add({
        'audience': 'student',
        'userId': studentId,
        'studentId': studentId,
        'studentName': d['studentName'] ?? '',
        'type': 'ticket_reply',
        'title': title,
        'body': subject.isEmpty ? body : '[$subject] $body',
        'ticketId': ticketId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // notification failure must never block the reply itself
    }
  }

  Future<void> updateStatus(String ticketId, String status) async {
    await _tickets.doc(ticketId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (status == 'Resolved') {
      await _notifyStudent(
        ticketId: ticketId,
        title: 'Your ticket was resolved',
        body: 'Your support ticket has been marked as resolved.',
      );
    }
  }
}