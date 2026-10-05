import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore collection: notifications
/// {
///   userId:    recipient (student uid),
///   type:      "invite" | "approved" | "rejected" | "info",
///   title, body,
///   sponsorId, sponsorName, scholarshipTitles (for invites),
///   isRead:    bool,
///   createdAt: serverTimestamp
/// }
class NotificationService {
  final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection("notifications");

  // No orderBy here on purpose -> no composite index needed.
  // Sorting (newest first) is done on the client.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamFor(String userId) {
    return _col.where("userId", isEqualTo: userId).snapshots();
  }

  Stream<int> unreadCount(String userId) {
    return streamFor(userId).map(
          (s) => s.docs.where((d) => d.data()["isRead"] != true).length,
    );
  }

  Future<void> markRead(String id) => _col.doc(id).update({"isRead": true});

  Future<void> markAllRead(String userId) async {
    final snap = await _col.where("userId", isEqualTo: userId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      if (d.data()["isRead"] != true) {
        batch.update(d.reference, {"isRead": true});
      }
    }
    await batch.commit();
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> send({
    required String userId,
    required String type,
    required String title,
    required String body,
    String audience = "student", // "student" | "sponsor"
    Map<String, dynamic> extra = const {},
  }) {
    return _col.add({
      "userId": userId,
      "audience": audience,
      "type": type,
      "title": title,
      "body": body,
      "isRead": false,
      "createdAt": FieldValue.serverTimestamp(),
      ...extra,
    });
  }

  /// One action -> a notification for the student AND one for the sponsor.
  /// Never throws (a failed notification must not break the real action).
  Future<void> sendPair({
    required String? studentId,
    required String? sponsorId,
    required String type,
    String? sponsorType,
    required String studentTitle,
    required String studentBody,
    required String sponsorTitle,
    required String sponsorBody,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      if (studentId != null && studentId.isNotEmpty) {
        await send(
          userId: studentId,
          audience: "student",
          type: type,
          title: studentTitle,
          body: studentBody,
          extra: {if (sponsorId != null) "sponsorId": sponsorId, ...extra},
        );
      }
      if (sponsorId != null && sponsorId.isNotEmpty) {
        await send(
          userId: sponsorId,
          audience: "sponsor",
          type: sponsorType ?? type,
          title: sponsorTitle,
          body: sponsorBody,
          extra: {if (studentId != null) "studentId": studentId, ...extra},
        );
      }
    } catch (e) {
      debugPrint("NOTIFY ERROR: $e");
    }
  }

  // ---------------- Invite to Apply (sponsor -> student) ----------------

  String inviteDocId(String sponsorId, String studentId) =>
      "invite_${sponsorId}_$studentId";

  Stream<DocumentSnapshot<Map<String, dynamic>>> inviteDocStream({
    required String sponsorId,
    required String studentId,
  }) {
    return _col.doc(inviteDocId(sponsorId, studentId)).snapshots();
  }

  /// Returns null on success, or an error/info message.
  Future<String?> inviteStudent({
    required String sponsorId,
    required String sponsorName,
    required String studentId,
    required List<String> scholarshipTitles,
    List<String> scholarshipIds = const [],
  }) async {
    final ref = _col.doc(inviteDocId(sponsorId, studentId));

    final existing = await ref.get();
    if (existing.exists) return "You have already invited this student.";

    await ref.set({
      "userId": studentId,
      "audience": "student",
      "type": "invite",
      "title": "You're invited to apply 🎓",
      "body":
      "$sponsorName found your profile matching ${scholarshipTitles.length} "
          "of their scholarship${scholarshipTitles.length == 1 ? '' : 's'}. "
          "Apply now!",
      "sponsorId": sponsorId,
      "sponsorName": sponsorName,
      "scholarshipTitles": scholarshipTitles,
      "scholarshipIds": scholarshipIds,
      "status": "invited",
      "isRead": false,
      "createdAt": FieldValue.serverTimestamp(),
    });
    return null;
  }

  // ---------------- Invited student applied (student -> sponsor) ----------------

  /// Call right after a student's application is saved successfully.
  /// If this sponsor had invited this student, the invite is marked "applied"
  /// and the sponsor gets an "Invited student applied" notification.
  /// Never throws. Returns true if a sponsor notification was sent.
  Future<bool> onStudentApplied({
    required String studentId,
    required String sponsorId,
    required String studentName,
    required String scholarshipTitle,
    String? applicationId,
  }) async {
    try {
      if (studentId.isEmpty || sponsorId.isEmpty) return false;

      final ref = _col.doc(inviteDocId(sponsorId, studentId));
      final snap = await ref.get();
      if (!snap.exists) return false; // student was not invited by this sponsor

      await ref.update({
        "status": "applied",
        "appliedAt": FieldValue.serverTimestamp(),
        "appliedTitles": FieldValue.arrayUnion([scholarshipTitle]),
      });

      await send(
        userId: sponsorId,
        audience: "sponsor",
        type: "invite_accepted",
        title: "Invited student applied 🎉",
        body: "$studentName accepted your invitation and applied for "
            "$scholarshipTitle. Review the application now.",
        extra: {
          "studentId": studentId,
          "studentName": studentName,
          "scholarshipTitle": scholarshipTitle,
          if (applicationId != null) "applicationId": applicationId,
        },
      );
      return true;
    } catch (e) {
      debugPrint("NOTIFY onStudentApplied ERROR: $e");
      return false;
    }
  }
}