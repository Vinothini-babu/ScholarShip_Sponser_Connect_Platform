import 'package:cloud_firestore/cloud_firestore.dart';

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
    Map<String, dynamic> extra = const {},
  }) {
    return _col.add({
      "userId": userId,
      "type": type,
      "title": title,
      "body": body,
      "isRead": false,
      "createdAt": FieldValue.serverTimestamp(),
      ...extra,
    });
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
  }) async {
    final ref = _col.doc(inviteDocId(sponsorId, studentId));

    final existing = await ref.get();
    if (existing.exists) return "You have already invited this student.";

    await ref.set({
      "userId": studentId,
      "type": "invite",
      "title": "You're invited to apply 🎓",
      "body":
      "$sponsorName found your profile matching ${scholarshipTitles.length} "
          "of their scholarship${scholarshipTitles.length == 1 ? '' : 's'}. "
          "Apply now!",
      "sponsorId": sponsorId,
      "sponsorName": sponsorName,
      "scholarshipTitles": scholarshipTitles,
      "isRead": false,
      "createdAt": FieldValue.serverTimestamp(),
    });
    return null;
  }
}