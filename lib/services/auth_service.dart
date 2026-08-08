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
    UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final String uid = userCredential.user!.uid;

    // Convert role into a safe collection name
    final String roleCollection =
    role.toLowerCase().trim();

    // Save user according to role
    await _firestore
        .collection("users")
        .doc(roleCollection)
        .collection(uid)
        .doc("profile")
        .set({
      "uid": uid,
      "name": name,
      "email": email,
      "mobile": mobile,
      "college": college,
      "course": course,
      "role": roleCollection,
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
      email: email,
      password: password,
    );
  }

  // =========================
  // GET USER ROLE
  // =========================

  Future<String> getUserRole() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("Current user is null");
    }

    final uid = user.uid;

    print("🔥 GET ROLE UID: $uid");

    final doc = await _firestore
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

    final data = doc.data();

    if (data == null) {
      throw Exception("User document data is null");
    }

    if (!data.containsKey("role")) {
      throw Exception("Role field not found in users/$uid");
    }

    return data["role"].toString().toLowerCase().trim();
  }

  // =========================
  // SIGN OUT
  // =========================

  Future<void> signOut() async {
    await _auth.signOut();
  }
}