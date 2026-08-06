import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;

  final String sponsorId; // NEW

  final String scholarshipId;
  final String scholarshipTitle;
  final String amount;
  final String status;
  final Timestamp appliedAt;

  ApplicationModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,

    required this.sponsorId, // NEW

    required this.scholarshipId,
    required this.scholarshipTitle,
    required this.amount,
    required this.status,
    required this.appliedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,

      'sponsorId': sponsorId, // NEW

      'scholarshipId': scholarshipId,
      'scholarshipTitle': scholarshipTitle,
      'amount': amount,
      'status': status,
      'appliedAt': appliedAt,
    };
  }

  factory ApplicationModel.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    return ApplicationModel(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',

      sponsorId: map['sponsorId'] ?? '', // NEW

      scholarshipId: map['scholarshipId'] ?? '',
      scholarshipTitle: map['scholarshipTitle'] ?? '',
      amount: map['amount'] ?? '',
      status: map['status'] ?? 'Pending',
      appliedAt: map['appliedAt'] ?? Timestamp.now(),
    );
  }
}