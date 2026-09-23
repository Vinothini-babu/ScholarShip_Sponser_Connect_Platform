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
    // No longer required — only the student signup form collects these.
    // Kept as plain (non-nullable) Strings with an empty default so
    // existing call sites that already pass them keep compiling unchanged.
    String college = "",
    String course = "",
    required String password,
    required String role,
    // Optional — currently only sent by the student signup screen.
    // Nullable so sponsor/admin signups (which don't collect these)
    // keep working without any change.
    DateTime? dob,
    String? state,
    String? district,
    String? rollNumber,
    String? annualIncome,
    String? yearOfStudy,
    String? category,
    // Sponsor-only fields — nullable so student/admin signups (which
    // don't collect these) are unaffected.
    String? organizationName,
    String? registrationNumber,
    String? proofDocumentUrl,
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
    final Map<String, dynamic> userData = {
      "uid": uid,
      "name": name,
      "email": email,
      "mobile": mobile,
      "role": userRole,
      "createdAt": FieldValue.serverTimestamp(),
    };

    // Student-only eligibility/profile fields — only added when supplied,
    // so sponsor/admin sign-ups (which don't pass them) are unaffected.
    if (college.isNotEmpty) userData["college"] = college;
    if (course.isNotEmpty) userData["course"] = course;
    if (dob != null) userData["dob"] = Timestamp.fromDate(dob);
    if (state != null && state.isNotEmpty) userData["state"] = state;
    if (district != null && district.isNotEmpty) userData["district"] = district;
    if (rollNumber != null && rollNumber.isNotEmpty) userData["rollNumber"] = rollNumber;
    if (annualIncome != null && annualIncome.isNotEmpty) {
      userData["annualIncome"] = num.tryParse(annualIncome) ?? annualIncome;
    }
    if (yearOfStudy != null && yearOfStudy.isNotEmpty) userData["yearOfStudy"] = yearOfStudy;
    if (category != null && category.isNotEmpty) userData["category"] = category;

    // Sponsor-only fields.
    if (organizationName != null && organizationName.isNotEmpty) {
      userData["organizationName"] = organizationName;
    }
    if (registrationNumber != null && registrationNumber.isNotEmpty) {
      userData["registrationNumber"] = registrationNumber;
    }
    if (proofDocumentUrl != null && proofDocumentUrl.isNotEmpty) {
      userData["proofDocumentUrl"] = proofDocumentUrl;
    }

    await _firestore.collection("users").doc(uid).set(userData);

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