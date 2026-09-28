import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // SIGN UP
  // ============================================================

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String mobile,

    // Student fields
    String college = "",
    String course = "",

    required String password,
    required String role,

    // Student-only optional fields
    DateTime? dob,
    String? state,
    String? district,
    String? rollNumber,
    String? annualIncome,
    String? yearOfStudy,
    String? category,

    // Sponsor-only fields
    String? organizationName,
    String? registrationNumber,
    String? proofDocumentUrl,
  }) async {
    // ==========================================================
    // 1. CREATE FIREBASE AUTH ACCOUNT
    // ==========================================================

    final UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Firebase Authentication UID
    final String uid = userCredential.user!.uid;

    // Normalize role
    final String userRole =
    role.toLowerCase().trim();

    print("====================================");
    print("🔥 ACCOUNT CREATED");
    print("UID  : $uid");
    print("Role : $userRole");
    print("Email: ${email.trim()}");
    print("====================================");

    // ==========================================================
    // 2. COMMON USER DATA
    // ==========================================================

    final Map<String, dynamic> userData = {
      "uid": uid,
      "name": name.trim(),
      "email": email.trim(),
      "mobile": mobile.trim(),
      "role": userRole,
      "createdAt": FieldValue.serverTimestamp(),
    };

    // ==========================================================
    // 3. STUDENT FIELDS
    // ==========================================================

    if (college.trim().isNotEmpty) {
      userData["college"] = college.trim();
    }

    if (course.trim().isNotEmpty) {
      userData["course"] = course.trim();
    }

    if (dob != null) {
      userData["dob"] = Timestamp.fromDate(dob);
    }

    if (state != null && state.trim().isNotEmpty) {
      userData["state"] = state.trim();
    }

    if (district != null && district.trim().isNotEmpty) {
      userData["district"] = district.trim();
    }

    if (rollNumber != null && rollNumber.trim().isNotEmpty) {
      userData["rollNumber"] = rollNumber.trim();
    }

    if (annualIncome != null &&
        annualIncome.trim().isNotEmpty) {
      userData["annualIncome"] =
          num.tryParse(annualIncome.trim()) ??
              annualIncome.trim();
    }

    if (yearOfStudy != null &&
        yearOfStudy.trim().isNotEmpty) {
      userData["yearOfStudy"] =
          yearOfStudy.trim();
    }

    if (category != null &&
        category.trim().isNotEmpty) {
      userData["category"] =
          category.trim();
    }

    // ==========================================================
    // 4. SPONSOR FIELDS
    // ==========================================================

    if (organizationName != null &&
        organizationName.trim().isNotEmpty) {
      userData["organizationName"] =
          organizationName.trim();
    }

    if (registrationNumber != null &&
        registrationNumber.trim().isNotEmpty) {
      userData["registrationNumber"] =
          registrationNumber.trim();
    }

    if (proofDocumentUrl != null &&
        proofDocumentUrl.trim().isNotEmpty) {
      userData["proofDocumentUrl"] =
          proofDocumentUrl.trim();
    }

    // ==========================================================
    // 5. SAVE COMMON USER DATA
    //
    // users/{uid}
    // ==========================================================

    await _firestore
        .collection("users")
        .doc(uid)
        .set(userData);

    print("🔥 Saved to users/$uid");

    // ==========================================================
    // 6. SAVE ROLE-SPECIFIC DATA
    //
    // Each role gets its own document shape — NOT a reuse of the
    // common `userData` map — so field names match what each
    // screen/collection actually expects.
    // ==========================================================

    if (userRole == "student") {
      // --------------------------------------------------------
      // students/{uid}
      // --------------------------------------------------------

      final Map<String, dynamic> studentData = {
        "name": name.trim(),
        "email": email.trim(),
        "mobile": mobile.trim(),
        "collegeName": college.trim(),
        "role": "student",
        "createdAt": FieldValue.serverTimestamp(),
      };

      if (course.trim().isNotEmpty) {
        studentData["course"] = course.trim();
      }
      if (dob != null) {
        studentData["dob"] = Timestamp.fromDate(dob);
      }
      if (state != null && state.trim().isNotEmpty) {
        studentData["state"] = state.trim();
      }
      if (district != null && district.trim().isNotEmpty) {
        studentData["district"] = district.trim();
      }
      if (rollNumber != null && rollNumber.trim().isNotEmpty) {
        studentData["rollNumber"] = rollNumber.trim();
      }
      if (annualIncome != null && annualIncome.trim().isNotEmpty) {
        studentData["annualIncome"] =
            num.tryParse(annualIncome.trim()) ?? annualIncome.trim();
      }
      if (yearOfStudy != null && yearOfStudy.trim().isNotEmpty) {
        studentData["yearOfStudy"] = yearOfStudy.trim();
      }
      if (category != null && category.trim().isNotEmpty) {
        studentData["category"] = category.trim();
      }

      await _firestore
          .collection("students")
          .doc(uid)
          .set(studentData);

      print("🎓 Saved to students/$uid");
    }

    else if (userRole == "sponsor") {
      // --------------------------------------------------------
      // sponsors/{uid}
      //
      // organizationName, registrationNumber, state, district,
      // contactPersonName, email, mobile, certificateUrl,
      // role, createdAt
      // --------------------------------------------------------

      final Map<String, dynamic> sponsorData = {
        "organizationName": (organizationName ?? "").trim(),
        "registrationNumber": (registrationNumber ?? "").trim(),
        "state": (state ?? "").trim(),
        "district": (district ?? "").trim(),
        "contactPersonName": name.trim(),
        "email": email.trim(),
        "mobile": mobile.trim(),
        "certificateUrl": (proofDocumentUrl ?? "").trim(),
        "role": "sponsor",
        "createdAt": FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection("sponsors")
          .doc(uid)
          .set(sponsorData);

      print("🤝 Saved to sponsors/$uid");
    }

    else if (userRole == "admin") {
      // --------------------------------------------------------
      // admins/{uid}
      // --------------------------------------------------------

      final Map<String, dynamic> adminData = {
        "name": name.trim(),
        "email": email.trim(),
        "role": "admin",
        "createdAt": FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection("admins")
          .doc(uid)
          .set(adminData);

      print("🛡️ Saved to admins/$uid");
    }

    else {
      print(
        "⚠️ Unknown role: $userRole",
      );
    }

    print("====================================");
    print("🔥 SIGN UP COMPLETED");
    print("UID  : $uid");
    print("Role : $userRole");
    print("====================================");

    return userCredential;
  }

  // ============================================================
  // SIGN IN
  // ============================================================

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ============================================================
  // GET USER ROLE
  //
  // Reads from:
  // users/{uid}
  //
  // We keep this because your existing LoginScreen
  // already uses getUserRole().
  // ============================================================

  Future<String> getUserRole() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        "Current user is null",
      );
    }

    final String uid = user.uid;

    print("🔥 GET ROLE UID: $uid");

    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestore
        .collection("users")
        .doc(uid)
        .get();

    print(
      "🔥 USER DOCUMENT EXISTS: ${doc.exists}",
    );

    print(
      "🔥 USER DOCUMENT DATA: ${doc.data()}",
    );

    if (!doc.exists) {
      throw Exception(
        "User profile not found in users/$uid",
      );
    }

    final Map<String, dynamic>? data =
    doc.data();

    if (data == null) {
      throw Exception(
        "User document data is null",
      );
    }

    final dynamic role =
    data["role"];

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

  // ============================================================
  // GET CURRENT USER DATA
  //
  // Common user data from:
  // users/{uid}
  // ============================================================

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestore
        .collection("users")
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  // ============================================================
  // GET STUDENT DATA
  //
  // students/{uid}
  // ============================================================

  Future<Map<String, dynamic>?> getStudentData() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestore
        .collection("students")
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  // ============================================================
  // GET SPONSOR DATA
  //
  // sponsors/{uid}
  // ============================================================

  Future<Map<String, dynamic>?> getSponsorData() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestore
        .collection("sponsors")
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  // ============================================================
  // GET ADMIN DATA
  //
  // admins/{uid}
  // ============================================================

  Future<Map<String, dynamic>?> getAdminData() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestore
        .collection("admins")
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    await _auth.signOut();
  }
}