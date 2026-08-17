import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/application_model.dart';

class ApplicationService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================================================
  // APPLY FOR SCHOLARSHIP - STUDENT
  // =========================================================

  Future<String> applyScholarship(
      ApplicationModel application,
      ) async {
    try {
      // Check if already applied
      final existing = await _firestore
          .collection("applications")
          .where(
        "studentId",
        isEqualTo: application.studentId,
      )
          .where(
        "scholarshipId",
        isEqualTo: application.scholarshipId,
      )
          .get();

      if (existing.docs.isNotEmpty) {
        return "Already Applied";
      }

      // Save application
      await _firestore
          .collection("applications")
          .add(
        application.toMap(),
      );

      return "Success";
    } catch (e) {
      return e.toString();
    }
  }

  // =========================================================
  // GET STUDENT APPLICATIONS
  // =========================================================

  Stream<List<ApplicationModel>> getStudentApplications(
      String studentId,
      ) {
    return _firestore
        .collection('applications')
        .where(
      'studentId',
      isEqualTo: studentId,
    )
        .orderBy(
      'appliedAt',
      descending: true,
    )
        .snapshots()
        .map((snapshot) {
      print(
        "Student Applications: ${snapshot.docs.length}",
      );

      return snapshot.docs.map((doc) {
        return ApplicationModel.fromMap(
          doc.data(),
          doc.id,
        );
      }).toList();
    });
  }

  // =========================================================
  // GET SPONSOR APPLICATIONS
  // =========================================================

  Stream<List<ApplicationModel>> getSponsorApplications(
      String sponsorId,
      ) {
    return _firestore
        .collection('applications')
        .where(
      'sponsorId',
      isEqualTo: sponsorId,
    )
        .orderBy(
      'appliedAt',
      descending: true,
    )
        .snapshots()
        .map((snapshot) {
      print(
        "Sponsor Applications: ${snapshot.docs.length}",
      );

      return snapshot.docs.map((doc) {
        return ApplicationModel.fromMap(
          doc.data(),
          doc.id,
        );
      }).toList();
    });
  }

  // =========================================================
  // UPDATE APPLICATION STATUS
  // =========================================================

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    await _firestore
        .collection('applications')
        .doc(applicationId)
        .update({
      'status': status,
    });
  }
}