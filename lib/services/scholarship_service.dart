import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scholarship_model.dart';

class ScholarshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ScholarshipModel>> getScholarships() {
    return _firestore
        .collection('scholarships')
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
}