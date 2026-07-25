import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String mobile,
    required String college,
    required String password,
    required String role,
  }) async {
    UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore
        .collection("users")
        .doc(userCredential.user!.uid)
        .set({
      "name": name,
      "email": email,
      "mobile": mobile,
      "college": college,
      "role": role,
    });

    return userCredential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<String> getUserRole() async {
    String uid = _auth.currentUser!.uid;

    DocumentSnapshot doc =
    await _firestore.collection("users").doc(uid).get();

    return doc["role"];
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}