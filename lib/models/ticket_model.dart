import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String id;
  final String studentId;
  final String studentName;
  final String subject;
  final String category; // Application / Document / Payment / Other
  final String description;
  final String status; // Open / In Progress / Resolved
  final DateTime createdAt;
  final DateTime updatedAt;

  TicketModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subject,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TicketModel(
      id: doc.id,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? 'Student',
      subject: d['subject'] ?? '',
      category: d['category'] ?? 'General',
      description: (d['description'] ?? d['message'] ?? '').toString(),
      status: d['status'] ?? 'Open',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ??
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'studentName': studentName,
    'subject': subject,
    'category': category,
    'description': description,
    'status': status,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class TicketReply {
  final String id;
  final String senderRole; // 'admin' or 'student'
  final String senderId;
  final String message;
  final DateTime createdAt;

  TicketReply({
    required this.id,
    required this.senderRole,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  factory TicketReply.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TicketReply(
      id: doc.id,
      senderRole: d['senderRole'] ?? 'admin',
      senderId: d['senderId'] ?? '',
      message: d['message'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}