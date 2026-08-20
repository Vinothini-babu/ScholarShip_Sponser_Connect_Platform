import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================
  // SIGN UP
  // =========================

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String mobile,
    required String college,
    required String course,
    required String password,
    required String role,
  }) async {
    // Create Firebase Authentication account
    final UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final String uid = userCredential.user!.uid;

    final String userRole =
    role.toLowerCase().trim();

    // IMPORTANT:
    // Store every user directly inside users/{uid}
    // This makes dashboard counts and role checking work correctly.
    await _firestore
        .collection("users")
        .doc(uid)
        .set({
      "uid": uid,
      "name": name,
      "email": email,
      "mobile": mobile,
      "college": college,
      "course": course,
      "role": userRole,
      "createdAt": FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  // =========================
  // SIGN IN
  // =========================

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // =========================
  // GET USER ROLE
  // =========================

  Future<String> getUserRole() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception("Current user is null");
    }

    final String uid = user.uid;

    print("🔥 GET ROLE UID: $uid");

    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestore
        .collection("users")
        .doc(uid)
        .get();

    print("🔥 USER DOCUMENT EXISTS: ${doc.exists}");
    print("🔥 USER DOCUMENT DATA: ${doc.data()}");

    if (!doc.exists) {
      throw Exception(
        "User profile not found in users/$uid",
      );
    }

    final Map<String, dynamic>? data = doc.data();

    if (data == null) {
      throw Exception(
        "User document data is null",
      );
    }

    final dynamic role = data["role"];

    if (role == null) {
      throw Exception(
        "Role field not found in users/$uid",
      );
    }

    return role
        .toString()
        .toLowerCase()
        .trim();
  }

  // =========================
  // GET CURRENT USER DATA
  // =========================

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final doc = await _firestore
        .collection("users")
        .doc(user.uid)
        .get();

    return doc.data();
  }

  // =========================
  // SIGN OUT
  // =========================

  Future<void> signOut() async {
    await _auth.signOut();
  }
}