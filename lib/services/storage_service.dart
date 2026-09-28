import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Uploads a locally-picked file (from file_picker) to Cloudinary and
/// returns its public URL.
///
/// Same public API as the old Firebase Storage version, so
/// scholarship_application_screen.dart and upload_semester_update_screen.dart
/// need NO changes.
class StorageService {
  // TODO: replace with your own values from the Cloudinary dashboard.
  static const String _cloudName = 'yisu0ubf';
  static const String _uploadPreset = 'scholarship_unsigned';

  /// Uploads [file] into Cloudinary folder [folder] and returns its
  /// secure download URL once the upload finishes.
  static Future<String> uploadFile({
    required File file,
    required String folder,
    required String fileName,
  }) async {
    // "auto" lets Cloudinary accept PDF, JPG and PNG with one endpoint.
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
    );

    // Cloudinary adds the extension itself for images/PDFs, so strip it
    // from the public id to avoid "file.pdf.pdf".
    final dot = fileName.lastIndexOf('.');
    final publicId = dot > 0 ? fileName.substring(0, dot) : fileName;

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      String message = 'Upload failed (${streamed.statusCode})';
      try {
        final err = jsonDecode(body)['error']?['message'];
        if (err != null) message = '$message: $err';
      } catch (_) {}
      throw Exception(message);
    }

    final url = jsonDecode(body)['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Upload succeeded but no URL was returned');
    }
    return url;
  }

  /// Builds a safe, collision-resistant file name from a display name
  /// (e.g. "Income Certificate") and the original file's extension —
  /// spaces/special characters stripped, timestamp appended.
  static String buildFileName(String label, String extension) {
    final safeLabel = label.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "${safeLabel}_$ts.$extension";
  }
}