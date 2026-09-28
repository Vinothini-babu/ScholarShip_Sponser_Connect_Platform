import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app.dart';
import 'firebase_options.dart';

// TEMPORARY diagnostic — remove once the dashboard data issue is fixed.
// Tries a simple read on the users collection and prints the result.
Future<void> _testFirestore(String label) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection("users")
        .limit(1)
        .get();
    debugPrint("✅ [$label] Firestore OK, docs: ${snap.docs.length}");
  } catch (e) {
    debugPrint("❌ [$label] Firestore error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Test 1: right after the default app starts, before SecondaryApp exists.
  await _testFirestore("before SecondaryApp");

  // Secondary named app — same Firebase project, but its own independent
  // Auth session. Used only by AdminService.createAdmin() so that creating
  // a new admin account doesn't sign the currently-logged-in admin out of
  // the app (which is what FirebaseAuth.instance.createUserWithEmailAndPassword
  // would otherwise do, since it auto-signs-in as the newly created user).
  await Firebase.initializeApp(
    name: "SecondaryApp",
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Test 2: after SecondaryApp is initialized — if this one fails but Test 1
  // passed, the second app is the culprit.
  await _testFirestore("after SecondaryApp");

  runApp(const ScholarshipSponsorConnectApp());
}