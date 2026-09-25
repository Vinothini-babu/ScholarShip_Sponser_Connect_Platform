import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a locally-picked file (from file_picker) to Firebase Storage and
/// returns its public download URL.
///
/// Used everywhere a student picks a document/marksheet that a sponsor must
/// later be able to open (application documents, semester-update
/// marksheets) — previously these screens saved the on-device local file
/// path straight into Firestore, which only ever worked on the student's
/// own device and left the sponsor's "View" button with nothing openable.
class StorageService {
  /// Uploads [file] to `folder/fileName` in the default Storage bucket and
  /// returns its download URL once the upload finishes.
  static Future<String> uploadFile({
    required File file,
    required String folder,
    required String fileName,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(folder).child(fileName);
    final uploadTask = await ref.putFile(file);
    return uploadTask.ref.getDownloadURL();
  }

  /// Builds a Storage-safe, collision-resistant file name from a display
  /// name (e.g. "Income Certificate") and the original file's extension —
  /// spaces/special characters stripped, timestamp appended.
  static String buildFileName(String label, String extension) {
    final safeLabel = label.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "${safeLabel}_$ts.$extension";
  }
}