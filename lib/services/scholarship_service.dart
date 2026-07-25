import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scholarship_model.dart';

class ScholarshipService {

  Stream<List<ScholarshipModel>> getScholarships() {
    return _firestore
        .collection("scholarships")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ScholarshipModel.fromMap(
          doc.data(),
          doc.id,
        );
      }).toList();
    });
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addScholarship({
    required String title,
    required String amount,
    required String description,
    required String deadline,
  }) async {
    await _firestore.collection("scholarships").add({
      "title": title,
      "amount": amount,
      "description": description,
      "deadline": deadline,
      "createdAt": Timestamp.now(),
    });
  }
}