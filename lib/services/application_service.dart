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
      // Awarded student (approved by any sponsor) cannot apply again
      final userDoc = await _firestore
          .collection("users")
          .doc(application.studentId)
          .get();

      if (userDoc.data()?["isAwarded"] == true) {
        return "You already have an awarded scholarship";
      }

      // Check if already applied
      final existing = await _firestore
          .collection("applications")
          .where("studentId", isEqualTo: application.studentId)
          .where("scholarshipId", isEqualTo: application.scholarshipId)
          .get();

      if (existing.docs.isNotEmpty) {
        return "Already Applied";
      }

      await _firestore.collection("applications").add(
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
        .where('studentId', isEqualTo: studentId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ApplicationModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // =========================================================
  // SPONSOR APPLICATIONS (privacy filtered)
  //
  // A student who was approved (awarded) by ANOTHER sponsor is hidden
  // here. Awarded by THIS sponsor -> still visible (renewals etc.).
  // Returns raw docs so dashboard + list screen share one filter.
  // =========================================================

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getVisibleSponsorApplicationDocs(String sponsorId) {
    return _firestore
        .collection('applications')
        .where('sponsorId', isEqualTo: sponsorId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final ids = snapshot.docs
          .map((d) => (d.data()['studentId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      final hidden = <String>{};

      await Future.wait(ids.map((id) async {
        try {
          final u = await _firestore.collection('users').doc(id).get();
          final d = u.data();
          if (d != null &&
              d['isAwarded'] == true &&
              d['awardedBy'] != sponsorId) {
            hidden.add(id);
          }
        } catch (_) {
          // if read fails, keep the application visible
        }
      }));

      return snapshot.docs
          .where((d) => !hidden.contains((d.data()['studentId'] ?? '').toString()))
          .toList();
    });
  }

  Stream<List<ApplicationModel>> getSponsorApplications(
      String sponsorId,
      ) {
    return getVisibleSponsorApplicationDocs(sponsorId).map((docs) {
      return docs
          .map((doc) => ApplicationModel.fromMap(doc.data(), doc.id))
          .toList();
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
        .update({'status': status});
  }

  // =========================================================
  // APPROVE / REJECT with award flag (batch write)
  // Returns null on success, or an error message.
  // =========================================================

  Future<String?> setStatusWithAward({
    required String applicationId,
    required String status, // "Approved" | "Rejected"
    required String sponsorId,
    required String? studentId,
    required String? scholarshipId,
    required Map<String, dynamic> extraAppFields,
    required bool wasApproved,
  }) async {
    final appRef = _firestore.collection('applications').doc(applicationId);
    final batch = _firestore.batch();

    if (status == "Approved" && studentId != null) {
      final u = await _firestore.collection('users').doc(studentId).get();
      final d = u.data();
      if (d?['isAwarded'] == true && d?['awardedBy'] != sponsorId) {
        return "This student has already been awarded by another sponsor.";
      }
    }

    batch.update(appRef, {
      'status': status,
      'statusHistory': FieldValue.arrayUnion([
        {'status': status, 'timestamp': Timestamp.now()},
      ]),
      ...extraAppFields,
    });

    if (studentId != null) {
      final userRef = _firestore.collection('users').doc(studentId);

      if (status == "Approved") {
        batch.update(userRef, {
          'isAwarded': true,
          'awardedBy': sponsorId,
          'awardedScholarshipId': scholarshipId,
          'awardedAt': FieldValue.serverTimestamp(),
        });
      } else if (status == "Rejected" && wasApproved) {
        // approval revoked -> student becomes visible/eligible again
        batch.update(userRef, {
          'isAwarded': false,
          'awardedBy': FieldValue.delete(),
          'awardedScholarshipId': FieldValue.delete(),
          'awardedAt': FieldValue.delete(),
        });
      }
    }

    await batch.commit();
    return null;
  }
}