import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/application_model.dart';
import 'notification_service.dart';

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

      final appRef = await _firestore.collection("applications").add(
        application.toMap(),
      );

      // notify sponsor (new application) + student (confirmation)
      final m = application.toMap();
      final sch = (m['scholarshipTitle'] ?? 'a scholarship').toString();
      final who = (m['studentName'] ?? 'A student').toString();
      await NotificationService().sendPair(
        studentId: application.studentId,
        sponsorId: m['sponsorId']?.toString(),
        type: 'applied',
        sponsorType: 'application_received',
        studentTitle: "Application Submitted ✅",
        studentBody:
        "Your application for $sch has been submitted. The sponsor will review it soon.",
        sponsorTitle: "New Application Received",
        sponsorBody: "$who applied for $sch. Open Applications to review it.",
      );

      // If this sponsor had invited this student, mark the invitation as
      // "applied" and tell the sponsor the invited student applied.
      await NotificationService().onStudentApplied(
        studentId: application.studentId,
        sponsorId: (m['sponsorId'] ?? '').toString(),
        studentName: who,
        scholarshipTitle: sch,
        applicationId: appRef.id,
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

    final appSnap = await appRef.get();
    final appData = appSnap.data() ?? <String, dynamic>{};

    if (status == "Approved" && appData['documentsVerified'] != true) {
      return "Verify the uploaded documents before approving.";
    }

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

      // notify the student about the decision
      final schTitle =
      (appData['scholarshipTitle'] ?? 'your scholarship').toString();
      batch.set(_firestore.collection('notifications').doc(), {
        'userId': studentId,
        'audience': 'student',
        'type': status == "Approved" ? 'approved' : 'rejected',
        'title': status == "Approved"
            ? "Application Approved 🎉"
            : "Application Update",
        'body': status == "Approved"
            ? "Congratulations! Your application for $schTitle has been approved."
            : "Your application for $schTitle was not approved this time.",
        'sponsorId': sponsorId,
        'applicationId': applicationId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // sponsor's own activity copy
      batch.set(_firestore.collection('notifications').doc(), {
        'userId': sponsorId,
        'audience': 'sponsor',
        'type': status == "Approved" ? 'approved' : 'rejected',
        'title': status == "Approved"
            ? "You approved an application"
            : "You rejected an application",
        'body':
        "${(appData['studentName'] ?? 'Student').toString()} · $schTitle",
        'studentId': studentId,
        'applicationId': applicationId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

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

  // =========================================================
  // THANK-YOU NOTE - STUDENT -> SPONSOR
  // Returns null on success, or an error message.
  // =========================================================

  Future<String?> sendThankYou({
    required String applicationId,
    required String message,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return "Please write a message first.";
    if (text.length > 300) return "Message is too long (max 300 characters).";

    final ref = _firestore.collection('applications').doc(applicationId);

    try {
      Map<String, dynamic>? appData;

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final d = snap.data();
        if (d == null) throw "Application not found.";
        if (d['status'] != 'Approved') {
          throw "You can send a thank-you only after approval.";
        }
        if (d['thankYouSent'] == true) {
          throw "You have already sent a thank-you note.";
        }
        appData = d;
        tx.update(ref, {
          'thankYouSent': true,
          'thankYouMessage': text,
          'thankYouAt': FieldValue.serverTimestamp(),
        });
      });

      // notify the sponsor (best effort, never fails the thank-you)
      try {
        final d = appData ?? <String, dynamic>{};
        final sponsorId = (d['sponsorId'] ?? '').toString();
        if (sponsorId.isNotEmpty) {
          final studentId = (d['studentId'] ?? d['uid'] ?? '').toString();
          var who = (d['studentName'] ?? '').toString().trim();
          if (who.isEmpty && studentId.isNotEmpty) {
            // studentName can be empty on the application -> read it from the profile
            final u = await _firestore.collection('users').doc(studentId).get();
            final ud = u.data() ?? <String, dynamic>{};
            who = (ud['name'] ?? ud['fullName'] ?? ud['studentName'] ?? '')
                .toString()
                .trim();
          }
          if (who.isEmpty) who = 'Your student';
          final sch = (d['scholarshipTitle'] ?? 'your scholarship').toString();
          await _firestore.collection('notifications').add({
            'userId': sponsorId,
            'audience': 'sponsor',
            'type': 'thank_you',
            'title': "Thank-you from $who 💛",
            'body': "$who sent you a thank-you note for $sch.",
            'note': text,
            'studentId': studentId,
            'applicationId': applicationId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      return null;
    } on FirebaseException catch (e) {
      return e.message ?? "Could not send. Please try again.";
    } catch (e) {
      return e.toString();
    }
  }
}