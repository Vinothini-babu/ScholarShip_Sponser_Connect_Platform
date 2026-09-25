import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Creates new admin accounts. There is no public admin signup — only an
/// already-logged-in admin can reach this — so it must not disturb their
/// own session in the process.
///
/// FirebaseAuth.instance.createUserWithEmailAndPassword() auto-signs-in as
/// the newly created user, which would log the current admin out. To avoid
/// that, account creation runs on the "SecondaryApp" Firebase app (a second
/// named app pointed at the same project, initialized in main.dart) — its
/// Auth session is completely separate from the default app's, so the
/// current admin's login is never touched.
class AdminService {
  static Future<String> createAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final secondaryApp = Firebase.app("SecondaryApp");
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        return "Failed to create admin account";
      }

      // Firestore isn't tied to a specific Auth instance, so this write
      // goes through the normal default-app connection.
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "name": name.trim(),
        "email": email.trim(),
        "role": "admin",
        "createdAt": FieldValue.serverTimestamp(),
      });

      // Clean up the secondary session immediately — it was only ever
      // needed to mint the new account.
      await secondaryAuth.signOut();

      return "Success";
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "email-already-in-use":
          return "An account with this email already exists";
        case "weak-password":
          return "Password is too weak — use at least 6 characters";
        case "invalid-email":
          return "Enter a valid email address";
        default:
          return e.message ?? "Failed to create admin account";
      }
    } catch (e) {
      return "Failed to create admin account: $e";
    }
  }
}