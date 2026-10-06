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

    // A student invited by one sponsor is reserved: no other sponsor can
    // invite them (a declined invitation frees the student again).
    try {
      final others = await _col
          .where("userId", isEqualTo: studentId)
          .where("type", isEqualTo: "invite")
          .get();
      for (final d in others.docs) {
        final m = d.data();
        if ((m["sponsorId"] ?? "") != sponsorId &&
            (m["status"] ?? "invited") != "declined" &&
            (m["status"] ?? "invited") != "withdrawn") {
          return "This student has already been invited by another sponsor.";
        }
      }
    } catch (e) {
      debugPrint("INVITE reserve check error: $e");
    }

    final existing = await ref.get();
    // a withdrawn invitation may be sent again
    if (existing.exists && existing.data()?["status"] != "withdrawn") {
      return "You have already invited this student.";
    }

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

  // ---------------- Privacy: hide invited students from other sponsors ----------------

  /// Student ids currently reserved by an invitation from a DIFFERENT sponsor
  /// (pending / accepted / applied). Use it to hide those students from this
  /// sponsor's "Suggested Students". A declined invitation frees the student.
  Stream<Set<String>> studentIdsInvitedByOthers(String mySponsorId) {
    return _col.where("type", isEqualTo: "invite").snapshots().map((s) {
      final out = <String>{};
      for (final d in s.docs) {
        final m = d.data();
        if ((m["sponsorId"] ?? "") == mySponsorId) continue;
        if ((m["status"] ?? "invited") == "declined") continue;
        if ((m["status"] ?? "invited") == "withdrawn") continue;
        final id = (m["userId"] ?? "").toString();
        if (id.isNotEmpty) out.add(id);
      }
      return out;
    });
  }

  // ---------------- Sponsor tools: reminder / withdraw ----------------

  /// Nudges the student about a pending / accepted invitation (max once per 24h).
  /// Returns null on success, or a message.
  Future<String?> sendInviteReminder({
    required String sponsorId,
    required String studentId,
  }) async {
    try {
      final ref = _col.doc(inviteDocId(sponsorId, studentId));
      final snap = await ref.get();
      final m = snap.data();
      if (m == null) return "Invitation not found.";

      final st = (m["status"] ?? "invited").toString();
      if (st == "applied") return "The student has already applied.";
      if (st == "declined" || st == "withdrawn") {
        return "This invitation is closed.";
      }

      final last = m["lastReminderAt"];
      if (last is Timestamp &&
          DateTime.now().difference(last.toDate()).inHours < 24) {
        return "You already sent a reminder in the last 24 hours.";
      }

      final sponsorName = (m["sponsorName"] ?? "A sponsor").toString();
      await ref.update({"lastReminderAt": FieldValue.serverTimestamp()});
      await send(
        userId: studentId,
        audience: "student",
        type: "invite_reminder",
        title: "Reminder from $sponsorName ⏰",
        body: st == "accepted"
            ? "$sponsorName is waiting for your application. Pick a "
            "scholarship and apply before the last date."
            : "$sponsorName invited you to apply. Open the invitation to "
            "accept it.",
        extra: {"sponsorId": sponsorId, "sponsorName": sponsorName},
      );
      return null;
    } catch (e) {
      debugPrint("NOTIFY sendInviteReminder ERROR: $e");
      return "Could not send the reminder. Please try again.";
    }
  }

  /// Sponsor cancels an invitation that has not been applied to yet.
  /// The student disappears from the "pending" list and is free for other
  /// sponsors again. Returns null on success, or a message.
  Future<String?> withdrawInvite({
    required String sponsorId,
    required String studentId,
  }) async {
    try {
      final ref = _col.doc(inviteDocId(sponsorId, studentId));
      final snap = await ref.get();
      final st = (snap.data()?["status"] ?? "invited").toString();
      if (!snap.exists) return "Invitation not found.";
      if (st == "applied") {
        return "The student has already applied, so it cannot be withdrawn.";
      }
      await ref.update({
        "status": "withdrawn",
        "withdrawnAt": FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint("NOTIFY withdrawInvite ERROR: $e");
      return "Could not withdraw the invitation. Please try again.";
    }
  }

  // ---------------- Student accepts / declines an invitation ----------------

  /// Returns null on success, or an error message.
  /// Marks the invite accepted/declined and notifies the sponsor.
  Future<String?> respondToInvite({
    required String sponsorId,
    required String studentId,
    required String studentName,
    required bool accept,
    List<String> scholarshipTitles = const [],
  }) async {
    try {
      if (sponsorId.isEmpty || studentId.isEmpty) {
        return "Invitation details are missing.";
      }
      final ref = _col.doc(inviteDocId(sponsorId, studentId));
      final snap = await ref.get();
      if (!snap.exists) return "This invitation is no longer available.";
      if (snap.data()?["status"] == "applied") return null;
      if (snap.data()?["status"] == "withdrawn") {
        return "This invitation was withdrawn by the sponsor.";
      }

      await ref.update({
        "status": accept ? "accepted" : "declined",
        "respondedAt": FieldValue.serverTimestamp(),
        "isRead": true,
      });

      final c = scholarshipTitles.length;
      await send(
        userId: sponsorId,
        audience: "sponsor",
        type: accept ? "invite_accepted" : "invite_declined",
        title: accept ? "Invitation accepted ✅" : "Invitation declined",
        body: accept
            ? "$studentName accepted your invitation and is reviewing "
            "${c == 0 ? 'your scholarships' : '$c scholarship${c == 1 ? '' : 's'}'}. "
            "An application may follow soon."
            : "$studentName declined your invitation.",
        extra: {"studentId": studentId, "studentName": studentName},
      );
      return null;
    } catch (e) {
      debugPrint("NOTIFY respondToInvite ERROR: $e");
      return "Could not update the invitation. Please try again.";
    }
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
        type: "invite_applied",
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