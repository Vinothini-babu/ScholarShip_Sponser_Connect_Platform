import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentCollege;

  final String sponsorId;

  final String scholarshipId;
  final String scholarshipTitle;
  final String amount;
  final String status;
  final Timestamp appliedAt;
  final Map<String, String> documents;

  ApplicationModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentCollege,
    required this.sponsorId,
    required this.scholarshipId,
    required this.scholarshipTitle,
    required this.amount,
    required this.status,
    required this.appliedAt,
    required this.documents,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'studentCollege': studentCollege,

      'sponsorId': sponsorId,

      'scholarshipId': scholarshipId,
      'scholarshipTitle': scholarshipTitle,
      'amount': amount,
      'status': status,
      'appliedAt': appliedAt,
      'documentPath': documents,
    };
  }

  factory ApplicationModel.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    final documentData =
        map['documentPath'] ?? map['documents'] ?? {};

    return ApplicationModel(
      id: id,

      studentId:
      map['studentId'] ?? '',

      studentName:
      map['studentName'] ?? '',

      studentEmail:
      map['studentEmail'] ?? '',

      studentCollege:
      map['studentCollege'] ?? '',

      sponsorId:
      map['sponsorId'] ?? '',

      scholarshipId:
      map['scholarshipId'] ?? '',

      scholarshipTitle:
      map['scholarshipTitle'] ?? '',

      amount:
      map['amount'] ?? '',

      status:
      map['status'] ?? 'Pending',

      appliedAt:
      map['appliedAt'] ?? Timestamp.now(),

      documents:
      Map<String, String>.from(
        documentData,
      ),
    );
  }
}