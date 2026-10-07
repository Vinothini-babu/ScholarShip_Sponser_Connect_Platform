import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Student <-> Sponsor chat, one conversation per application.
///
/// applications/{applicationId}/messages/{messageId}
///   text, senderId, senderRole ("student" | "sponsor"), createdAt
///
/// On the application document itself we keep:
///   lastMessage, lastMessageAt, lastMessageBy, lastMessageRole,
///   chatUnreadStudent, chatUnreadSponsor   (unread counters)
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _app(String applicationId) =>
      _db.collection("applications").doc(applicationId);

  CollectionReference<Map<String, dynamic>> _msgs(String applicationId) =>
      _app(applicationId).collection("messages");

  static String unreadField(String role) =>
      role == "student" ? "chatUnreadStudent" : "chatUnreadSponsor";

  static int _asInt(dynamic v) => v is num ? v.toInt() : 0;

  // Single-field orderBy -> no composite index needed.
  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String applicationId) {
    return _msgs(applicationId)
        .orderBy("createdAt", descending: true)
        .limit(300)
        .snapshots();
  }

  /// Unread messages for [myRole] on this application (live).
  Stream<int> unreadFor(String applicationId, String myRole) {
    return _app(applicationId)
        .snapshots()
        .map((s) => _asInt(s.data()?[unreadField(myRole)]));
  }

  /// Resets the unread counter of [myRole] to 0. Never throws.
  Future<void> markRead(String applicationId, String myRole) async {
    try {
      final ref = _app(applicationId);
      final snap = await ref.get();
      if (_asInt(snap.data()?[unreadField(myRole)]) > 0) {
        await ref.update({unreadField(myRole): 0});
      }
    } catch (e) {
      debugPrint("CHAT markRead ERROR: $e");
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> send({
    required String applicationId,
    required String myRole, // "student" | "sponsor"
    required String text,
  }) async {
    final msg = text.trim();
    if (msg.isEmpty) return null;
    if (msg.length > 1000) return "Message is too long (max 1000 characters).";

    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return "Please log in again.";

    try {
      final appSnap = await _app(applicationId).get();
      final app = appSnap.data();
      if (app == null) return "Application not found.";

      final otherRole = myRole == "student" ? "sponsor" : "student";
      final otherUnread = _asInt(app[unreadField(otherRole)]);
      final otherId = await _otherUserId(app, otherRole);

      final preview = msg.length > 80 ? "${msg.substring(0, 80)}…" : msg;

      final batch = _db.batch();
      batch.set(_msgs(applicationId).doc(), {
        "text": msg,
        "senderId": me.uid,
        "senderRole": myRole,
        "createdAt": FieldValue.serverTimestamp(),
      });
      batch.update(_app(applicationId), {
        "lastMessage": preview,
        "lastMessageAt": FieldValue.serverTimestamp(),
        "lastMessageBy": me.uid,
        "lastMessageRole": myRole,
        unreadField(otherRole): FieldValue.increment(1),
      });
      await batch.commit();

      // Only the FIRST unread message triggers a bell notification, so a
      // long conversation does not flood the notification screen.
      if (otherUnread == 0 && otherId.isNotEmpty) {
        await _notifyOther(
          otherId: otherId,
          otherRole: otherRole,
          myRole: myRole,
          myUid: me.uid,
          preview: preview,
          applicationId: applicationId,
          scholarshipTitle: (app["scholarshipTitle"] ?? "").toString(),
        );
      }
      return null;
    } catch (e) {
      debugPrint("CHAT send ERROR: $e");
      return "Could not send the message. Please try again.";
    }
  }

  Future<String> _otherUserId(
      Map<String, dynamic> app, String otherRole) async {
    if (otherRole == "student") {
      return (app["studentId"] ?? app["uid"] ?? "").toString();
    }
    final direct = (app["sponsorId"] ?? "").toString();
    if (direct.isNotEmpty) return direct;

    // fallback: the sponsor who owns the scholarship
    final sid = (app["scholarshipId"] ?? "").toString();
    if (sid.isEmpty) return "";
    final sch = await _db.collection("scholarships").doc(sid).get();
    return (sch.data()?["sponsorId"] ?? "").toString();
  }

  Future<void> _notifyOther({
    required String otherId,
    required String otherRole,
    required String myRole,
    required String myUid,
    required String preview,
    required String applicationId,
    required String scholarshipTitle,
  }) async {
    try {
      final meDoc = await _db.collection("users").doc(myUid).get();
      final d = meDoc.data() ?? {};
      String name = (myRole == "sponsor"
          ? (d["organizationName"] ?? d["name"])
          : d["name"])
          ?.toString()
          .trim() ??
          "";
      if (name.isEmpty) name = myRole == "sponsor" ? "Your sponsor" : "A student";

      await NotificationService().send(
        userId: otherId,
        audience: otherRole,
        type: "message",
        title: "New message from $name 💬",
        body: scholarshipTitle.isEmpty
            ? preview
            : "$scholarshipTitle · $preview",
        extra: {
          "applicationId": applicationId,
          "senderId": myUid,
          "senderRole": myRole,
        },
      );
    } catch (e) {
      // a failed notification must never break sending
      debugPrint("CHAT notify ERROR: $e");
    }
  }
}