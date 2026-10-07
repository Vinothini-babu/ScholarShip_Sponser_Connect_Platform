import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Firestore collection: feedback
/// {
///   userId, role ("student" | "sponsor"), name,
///   rating (1-5), category, message,
///   source: "general" | "application_approved" | "application_rejected",
///   applicationId?, scholarshipTitle?,
///   status: "new" | "reviewed",
///   adminReply?, repliedAt?, createdAt
/// }
class FeedbackService {
  static const List<String> categories = [
    "App experience",
    "Scholarship process",
    "Support",
    "Suggestion",
    "Other",
  ];

  final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection("feedback");

  // No orderBy on purpose (no composite index needed) - sort on the client.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAll() => _col.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMine(String uid) =>
      _col.where("userId", isEqualTo: uid).snapshots();

  /// Number of feedback items the admin has not reviewed yet.
  Stream<int> newCount() => _col.snapshots().map(
        (s) => s.docs
        .where((d) => (d.data()["status"] ?? "new") == "new")
        .length,
  );

  /// Returns null on success, or an error message.
  Future<String?> submit({
    required int rating,
    required String category,
    required String message,
    String source = "general",
    String? applicationId,
    String? scholarshipTitle,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Please sign in again.";

      if (applicationId != null && applicationId.isNotEmpty) {
        final existing = await _col
            .where("userId", isEqualTo: user.uid)
            .where("applicationId", isEqualTo: applicationId)
            .get();
        if (existing.docs.isNotEmpty) {
          return "You have already shared feedback for this application.";
        }
      }

      final u = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      final d = u.data() ?? <String, dynamic>{};
      final role = (d["role"] ?? "student").toString().trim().toLowerCase();

      String pick(List<String> keys) {
        for (final k in keys) {
          final v = (d[k] ?? "").toString().trim();
          if (v.isNotEmpty) return v;
        }
        return "";
      }

      final name = role == "sponsor"
          ? pick(["organizationName", "name"])
          : pick(["name", "fullName"]);

      await _col.add({
        "userId": user.uid,
        "role": role,
        "name": name.isEmpty ? "Anonymous" : name,
        "email": pick(["email"]),
        "rating": rating,
        "category": category,
        "message": message.trim(),
        "source": source,
        if (applicationId != null) "applicationId": applicationId,
        if (scholarshipTitle != null) "scholarshipTitle": scholarshipTitle,
        "status": "new",
        "createdAt": FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint("FEEDBACK submit ERROR: $e");
      return "Could not submit feedback. Please try again.";
    }
  }

  Future<void> setReviewed(String id, bool reviewed) =>
      _col.doc(id).update({"status": reviewed ? "reviewed" : "new"});

  /// Admin reply -> saved on the feedback + notification to the user.
  /// Returns null on success, or an error message.
  Future<String?> reply({
    required String id,
    required String userId,
    required String role,
    required String text,
  }) async {
    try {
      await _col.doc(id).update({
        "adminReply": text.trim(),
        "repliedAt": FieldValue.serverTimestamp(),
        "status": "reviewed",
      });
      await NotificationService().send(
        userId: userId,
        audience: role == "sponsor" ? "sponsor" : "student",
        type: "feedback_reply",
        title: "Admin replied to your feedback 💬",
        body: text.trim(),
        extra: {"feedbackId": id},
      );
      return null;
    } catch (e) {
      debugPrint("FEEDBACK reply ERROR: $e");
      return "Could not send the reply. Please try again.";
    }
  }
}