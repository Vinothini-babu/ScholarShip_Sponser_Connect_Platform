import 'package:cloud_firestore/cloud_firestore.dart';

class SavedScholarshipService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> saveScholarship({
    required String studentId,
    required String scholarshipId,
    required String title,
    required String amount,
    required String lastDate,
  }) async {
    final existing = await _firestore
        .collection("saved_scholarships")
        .where("studentId", isEqualTo: studentId)
        .where("scholarshipId", isEqualTo: scholarshipId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return;
    }

    await _firestore
        .collection("saved_scholarships")
        .add({
      "studentId": studentId,
      "scholarshipId": scholarshipId,
      "title": title,
      "amount": amount,
      "lastDate": lastDate,
      "savedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeSavedScholarship({
    required String studentId,
    required String scholarshipId,
  }) async {
    final snapshot = await _firestore
        .collection("saved_scholarships")
        .where("studentId", isEqualTo: studentId)
        .where("scholarshipId", isEqualTo: scholarshipId)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Stream<bool> isSaved({
    required String studentId,
    required String scholarshipId,
  }) {
    return _firestore
        .collection("saved_scholarships")
        .where("studentId", isEqualTo: studentId)
        .where("scholarshipId", isEqualTo: scholarshipId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.isNotEmpty;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
  getSavedScholarships(String studentId) {
    return _firestore
        .collection("saved_scholarships")
        .where("studentId", isEqualTo: studentId)
        .snapshots();
  }

  // ⭐ Real-time Saved Count
  Stream<int> getSavedCount(String studentId) {
    return _firestore
        .collection("saved_scholarships")
        .where("studentId", isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.length;
    });
  }
}