import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Secondary named app — same Firebase project, but its own independent
  // Auth session. Used only by AdminService.createAdmin() so that creating
  // a new admin account doesn't sign the currently-logged-in admin out of
  // the app (which is what FirebaseAuth.instance.createUserWithEmailAndPassword
  // would otherwise do, since it auto-signs-in as the newly created user).
  await Firebase.initializeApp(
    name: "SecondaryApp",
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ScholarshipSponsorConnectApp());
}