import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  Future<void> applyScholarship({
    required String scholarshipId,
    required String scholarshipTitle,
  }) async {

    final user = _auth.currentUser!;

    final studentDoc = await _firestore
        .collection("users")
        .doc(user.uid)
        .get();

    final studentData = studentDoc.data()!;

    await _firestore.collection("applications").add({

      "studentId": user.uid,
      "studentName": studentData["name"],
      "studentEmail": studentData["email"],
      "studentMobile": studentData["mobile"],
      "studentCollege": studentData["college"],

      "scholarshipId": scholarshipId,
      "scholarshipTitle": scholarshipTitle,

      "status": "Pending",

      "appliedAt": Timestamp.now(),

    });

  }
}