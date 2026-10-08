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

  static String notifField(String role) =>
      role == "student" ? "chatNotifAtStudent" : "chatNotifAtSponsor";

  static int _asInt(dynamic v) => v is num ? v.toInt() : 0;

  /// Who am I in THIS application? Decided from the logged-in uid, so a
  /// wrongly passed role can never send / notify as the wrong person.
  static String roleOf(Map<String, dynamic>? app, String uid, String fallback) {
    if (app == null || uid.isEmpty) return fallback;
    final studentId = (app["studentId"] ?? app["uid"] ?? "").toString();
    if (studentId.isEmpty) return fallback;
    return uid == studentId ? "student" : "sponsor";
  }

  static int unreadCount(Map<String, dynamic> app, String role) =>
      _asInt(app[unreadField(role)]);

  Future<String> roleFor(String applicationId, String fallback) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      final snap = await _app(applicationId).get();
      return roleOf(snap.data(), uid, fallback);
    } catch (_) {
      return fallback;
    }
  }

  // Single-field orderBy -> no composite index needed.
  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String applicationId) {
    return _msgs(applicationId)
        .orderBy("createdAt", descending: true)
        .limit(300)
        .snapshots();
  }

  /// Unread messages for [myRole] on this application (live).
  Stream<int> unreadFor(String applicationId, String myRole) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return _app(applicationId).snapshots().map((s) {
      final d = s.data();
      if (d == null) return 0;
      return unreadCount(d, roleOf(d, uid, myRole));
    });
  }

  /// Resets the unread counter of [myRole] to 0. Never throws.
  Future<void> markRead(String applicationId, String myRole) async {
    try {
      final ref = _app(applicationId);
      final snap = await ref.get();
      myRole = roleOf(snap.data(),
          FirebaseAuth.instance.currentUser?.uid ?? "", myRole);
      if (_asInt(snap.data()?[unreadField(myRole)]) > 0) {
        await ref.update({unreadField(myRole): 0});
      }
    } catch (e) {
      debugPrint("CHAT markRead ERROR: $e");
    }
    await _markChatNotificationsRead(applicationId);
  }

  /// Chat is open -> the bell notifications of this conversation are read.
  Future<void> _markChatNotificationsRead(String applicationId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await _db
          .collection("notifications")
          .where("userId", isEqualTo: uid)
          .where("type", isEqualTo: "message")
          .get();
      final batch = _db.batch();
      var n = 0;
      for (final d in snap.docs) {
        final m = d.data();
        if (m["isRead"] != true &&
            (m["applicationId"] ?? "").toString() == applicationId) {
          batch.update(d.reference, {"isRead": true});
          n++;
        }
      }
      if (n > 0) await batch.commit();
    } catch (e) {
      debugPrint("CHAT mark notifications read ERROR: $e");
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

      // trust the logged-in user, not the role passed by the caller
      myRole = roleOf(app, me.uid, myRole);

      final otherRole = myRole == "student" ? "sponsor" : "student";
      final otherUnread = _asInt(app[unreadField(otherRole)]);
      final otherId = await _otherUserId(app, otherRole, me.uid);

      debugPrint("CHAT send -> me=${me.uid} role=$myRole "
          "other=$otherId otherRole=$otherRole "
          "appStudent=${app["studentId"]} appSponsor=${app["sponsorId"]}");

      final preview = msg.length > 80 ? "${msg.substring(0, 80)}…" : msg;

      // Notify on the first unread message, AND again if the last chat
      // notification for this person is older than 60 seconds (so a new
      // message is never silently swallowed).
      final lastNotif = app[notifField(otherRole)];
      final notifyOther = otherId.isNotEmpty &&
          otherId != me.uid &&
          (otherUnread == 0 ||
              lastNotif is! Timestamp ||
              DateTime.now().difference(lastNotif.toDate()).inSeconds > 60);

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
        if (notifyOther) notifField(otherRole): FieldValue.serverTimestamp(),
      });
      await batch.commit();

      // Only the FIRST unread message triggers a bell notification, so a
      // long conversation does not flood the notification screen.
      if (notifyOther) {
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

  static String _firstId(Map<String, dynamic>? m, List<String> keys,
      {String exclude = ""}) {
    if (m == null) return "";
    for (final k in keys) {
      final v = (m[k] ?? "").toString().trim();
      if (v.isNotEmpty && v != exclude) return v;
    }
    return "";
  }

  /// uid of the OTHER person in this application (never my own uid).
  Future<String> _otherUserId(
      Map<String, dynamic> app, String otherRole, String myUid) async {
    if (otherRole == "student") {
      return _firstId(
        app,
        ["studentId", "uid", "userId", "studentUid"],
        exclude: myUid,
      );
    }

    final direct = _firstId(
      app,
      ["sponsorId", "sponsorUid", "sponsorUID"],
      exclude: myUid,
    );
    if (direct.isNotEmpty) return direct;

    // fallback: the sponsor who owns the scholarship
    final sid = (app["scholarshipId"] ?? "").toString();
    if (sid.isEmpty) return "";
    final sch = await _db.collection("scholarships").doc(sid).get();
    return _firstId(
      sch.data(),
      ["sponsorId", "sponsorUid", "createdBy", "ownerId", "uid", "userId"],
      exclude: myUid,
    );
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
        title: myRole == "sponsor"
            ? "New message from sponsor $name 💬"
            : "New message from student $name 💬",
        body: scholarshipTitle.isEmpty
            ? preview
            : "$scholarshipTitle · $preview",
        extra: {
          "applicationId": applicationId,
          "senderId": myUid,
          "senderRole": myRole,
          "senderName": name,
          "scholarshipTitle": scholarshipTitle,
        },
      );
    } catch (e) {
      // a failed notification must never break sending
      debugPrint("CHAT notify ERROR: $e");
    }
  }
}