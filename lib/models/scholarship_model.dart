import 'package:cloud_firestore/cloud_firestore.dart';

class ScholarshipModel {
  final String id;
  final String title;
  final String description;
  final String amount;
  final String lastDate;
  final String eligibility;
  final String sponsorName;
  final String sponsorId;
  final String scholarshipId;

  ScholarshipModel({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.lastDate,
    required this.eligibility,
    required this.sponsorName,
    required this.sponsorId,
    required this.scholarshipId,

  });

  factory ScholarshipModel.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    Timestamp? timestamp = map['lastDate'];

    return ScholarshipModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: map['amount'] ?? '',
      lastDate: timestamp != null
          ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}"
          : '',
      eligibility: map['eligibility'] ?? '',
      sponsorName: map['sponsorName'] ?? '',
      sponsorId: map['sponsorId'] ?? '',
      scholarshipId: map['scholarshipId'] ?? '',
    );
  }
}