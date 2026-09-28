import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../auth/role_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _maxContentWidth = 1240;

  static const List<String> _categoryOptions = [
    "General",
    "OBC",
    "MBC",
    "SC",
    "ST",
    "EWS",
    "Other",
  ];

  bool _uploadingPhoto = false;

  // Decoded-photo cache so the base64 string isn't re-decoded on every rebuild.
  String? _cachedPhotoB64;
  Uint8List? _cachedPhotoBytes;

  // ==========================================================
  // HELPERS
  // ==========================================================

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _read(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Uint8List? _photoBytes(String? b64) {
    if (b64 == null || b64.isEmpty) {
      _cachedPhotoB64 = null;
      _cachedPhotoBytes = null;
      return null;
    }
    if (b64 == _cachedPhotoB64) return _cachedPhotoBytes;
    try {
      _cachedPhotoBytes = base64Decode(b64);
      _cachedPhotoB64 = b64;
    } catch (_) {
      _cachedPhotoBytes = null;
      _cachedPhotoB64 = null;
    }
    return _cachedPhotoBytes;
  }

  String _formatIncome(String? raw) {
    if (raw == null) return "Not added";
    final n = num.tryParse(raw);
    if (n == null) return raw;
    final s = n.round().toString();
    if (s.length <= 3) return "₹$s";

    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return "₹${parts.join(',')},$last3";
  }

  String _formatPercent(String? raw) {
    if (raw == null) return "Not added";
    final n = double.tryParse(raw);
    if (n == null) return raw;
    return n % 1 == 0 ? "${n.toInt()}%" : "${n.toStringAsFixed(1)}%";
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : "${s[0].toUpperCase()}${s.substring(1)}";

  // ==========================================================
  // PROFILE PHOTO
  //
  // Picks an image, center-crops it to a 256x256 square, and stores it
  // as a base64 string in users/{uid}.photoBase64.
  // (No Firebase Storage needed — works on the free Spark plan.)
  // ==========================================================

  Future<Uint8List> _squareThumbnail(Uint8List bytes) async {
    const double outSize = 256;

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image src = frame.image;

    final double side = math.min(src.width, src.height).toDouble();
    final Rect srcRect = Rect.fromLTWH(
      (src.width - side) / 2,
      (src.height - side) / 2,
      side,
      side,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      srcRect,
      const Rect.fromLTWH(0, 0, outSize, outSize),
      Paint()..filterQuality = FilterQuality.high,
    );

    final ui.Image out = await recorder
        .endRecording()
        .toImage(outSize.toInt(), outSize.toInt());
    final ByteData? data = await out.toByteData(format: ui.ImageByteFormat.png);

    src.dispose();
    out.dispose();

    if (data == null) {
      throw Exception("Could not process the selected image");
    }
    return data.buffer.asUint8List();
  }

  Future<void> _pickAndUploadPhoto(String uid) async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (file == null) return;

      final String? path = file.path;

      if (path == null) {
        _snack("Could not read the selected image");
        return;
      }

      final Uint8List raw = await File(path).readAsBytes();

      if (raw.lengthInBytes > 10 * 1024 * 1024) {
        _snack("Image is too large. Please choose one under 10 MB.");
        return;
      }

      setState(() => _uploadingPhoto = true);

      final Uint8List thumb = await _squareThumbnail(raw);

      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "photoBase64": base64Encode(thumb),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      _snack("Profile photo updated");
    } catch (e) {
      _snack("Could not update photo: $e");
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto(String uid) async {
    try {
      setState(() => _uploadingPhoto = true);

      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "photoBase64": FieldValue.delete(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      _snack("Profile photo removed");
    } catch (e) {
      _snack("Could not remove photo: $e");
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showPhotoOptions(String uid, bool hasPhoto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Profile Photo",
                  style: AppTextStyles.title.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo_library_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(hasPhoto ? "Choose a new photo" : "Choose a photo"),
                  subtitle: const Text("JPG, PNG or WEBP"),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadPhoto(uid);
                  },
                ),
                if (hasPhoto)
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 20),
                    ),
                    title: Text(
                      "Remove photo",
                      style: TextStyle(color: AppColors.error),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _removePhoto(uid);
                    },
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    final String uid = user.uid;

    final profileStream =
    FirebaseFirestore.instance.collection("users").doc(uid).snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Something went wrong.\n\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off_rounded, size: 55, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    "Profile not found",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Please complete your profile first.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final Map<String, dynamic> data = snapshot.data!.data() ?? {};

          final String name = _read(data, "name") ?? "Student";
          final String email = _read(data, "email") ?? user.email ?? "Not added";
          final String role = _capitalize(_read(data, "role") ?? "student");

          final String? college =
              _read(data, "college") ?? _read(data, "collegeName");
          final String? course = _read(data, "course");
          final String? phone = _read(data, "mobile");
          final String? category = _read(data, "category");
          final String? percentage = _read(data, "percentage");
          final String? income = _read(data, "annualIncome");
          final String? yearOfStudy = _read(data, "yearOfStudy");
          final String? rollNumber = _read(data, "rollNumber");
          final String? district = _read(data, "district");
          final String? state = _read(data, "state");

          String? dobText;
          final dynamic dob = data["dob"];
          if (dob is Timestamp) {
            final d = dob.toDate();
            dobText = "${d.day.toString().padLeft(2, '0')}/"
                "${d.month.toString().padLeft(2, '0')}/${d.year}";
          }

          final String locationText = [district, state]
              .where((e) => e != null && e.isNotEmpty)
              .join(", ");
          final String? location = locationText.isEmpty ? null : locationText;

          final Uint8List? photo = _photoBytes(_read(data, "photoBase64"));

          final Widget personalCard = _SectionCard(
            title: "Personal Information",
            icon: Icons.person_outline_rounded,
            rows: [
              _InfoRow(
                icon: Icons.email_rounded,
                label: "Email",
                value: email,
              ),
              _InfoRow(
                icon: Icons.phone_rounded,
                label: "Phone",
                value: phone ?? "Not added",
              ),
              if (dobText != null)
                _InfoRow(
                  icon: Icons.cake_rounded,
                  label: "Date of Birth",
                  value: dobText,
                ),
              if (location != null)
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: "Location",
                  value: location,
                ),
            ],
          );

          final Widget academicCard = _SectionCard(
            title: "Academic Details",
            icon: Icons.school_outlined,
            rows: [
              _InfoRow(
                icon: Icons.school_rounded,
                label: "College",
                value: college ?? "Not added",
              ),
              _InfoRow(
                icon: Icons.menu_book_rounded,
                label: "Course",
                value: course ?? "Not added",
              ),
              if (yearOfStudy != null)
                _InfoRow(
                  icon: Icons.timeline_rounded,
                  label: "Year of Study",
                  value: yearOfStudy,
                ),
              if (rollNumber != null)
                _InfoRow(
                  icon: Icons.badge_rounded,
                  label: "Roll Number",
                  value: rollNumber,
                ),
            ],
          );

          final Widget editButton = SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _showEditProfileDialog(
                uid: uid,
                email: email,
                data: data,
              ),
              icon: const Icon(Icons.edit_rounded, size: 19),
              label: const Text(
                "Edit Profile",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          );

          final Widget logoutButton = SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();

                if (!context.mounted) return;

                // Clears the whole navigation stack so back/swipe
                // can't return into the dashboard after logout.
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen(),
                  ),
                      (route) => false,
                );
              },
              icon: Icon(
                Icons.logout_rounded,
                size: 19,
                color: AppColors.error,
              ),
              label: Text(
                "Logout",
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.error,
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          );

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(
                  name: name,
                  role: role,
                  photo: photo,
                  uid: uid,
                ),

                // Pulled up so the stat cards overlap the header curve.
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(maxWidth: _maxContentWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            // ---- Quick stats ----
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.percent_rounded,
                                    label: "Percentage",
                                    value: _formatPercent(percentage),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.currency_rupee_rounded,
                                    label: "Annual Income",
                                    value: _formatIncome(income),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.category_rounded,
                                    label: "Category",
                                    value: category ?? "Not added",
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            LayoutBuilder(
                              builder: (layoutContext, constraints) {
                                final bool wide = constraints.maxWidth >= 860;

                                if (wide) {
                                  return Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: personalCard),
                                          const SizedBox(width: 16),
                                          Expanded(child: academicCard),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(child: editButton),
                                          const SizedBox(width: 16),
                                          Expanded(child: logoutButton),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    personalCard,
                                    const SizedBox(height: 16),
                                    academicCard,
                                    const SizedBox(height: 26),
                                    editButton,
                                    const SizedBox(height: 12),
                                    logoutButton,
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // HEADER + AVATAR
  // ==========================================================

  Widget _buildHeader({
    required String name,
    required String role,
    required Uint8List? photo,
    required String uid,
  }) {
    const radius = BorderRadius.only(
      bottomLeft: Radius.circular(36),
      bottomRight: Radius.circular(36),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: _bubble(170, 0.07)),
            Positioned(bottom: -60, left: -40, child: _bubble(190, 0.05)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 64),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Navigator.canPop(context)
                              ? IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.white,
                            onPressed: () => Navigator.pop(context),
                          )
                              : null,
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              "My Profile",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildAvatar(photo: photo, uid: uid, name: name),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(
                          color: Colors.white,
                          fontSize: 23,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Text(
                        role,
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  Widget _buildAvatar({
    required Uint8List? photo,
    required String uid,
    required String name,
  }) {
    final String initial =
    name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : "S";

    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: SizedBox(
                width: 112,
                height: 112,
                child: photo != null
                    ? Image.memory(
                  photo,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
                    : Container(
                  color: Colors.white.withOpacity(0.15),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Upload progress overlay
          if (_uploadingPhoto)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black45,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Camera badge
          Positioned(
            right: 0,
            bottom: 2,
            child: Material(
              color: AppColors.secondary,
              elevation: 3,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white, width: 2.5),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _uploadingPhoto
                    ? null
                    : () => _showPhotoOptions(uid, photo != null),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EDIT PROFILE DIALOG
  // ==========================================================

  InputDecoration _inputDecoration(String label, IconData icon,
      {String? helper}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      border: border(Colors.transparent),
      enabledBorder: border(AppColors.textSecondary.withOpacity(0.12)),
      disabledBorder: border(AppColors.textSecondary.withOpacity(0.08)),
      focusedBorder: border(AppColors.primary, 1.4),
    );
  }

  void _showEditProfileDialog({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
  }) {
    // NOTE: empty string (not "Not added") so saving without touching a
    // field never overwrites real data with junk/zero.
    final nameC = TextEditingController(text: _read(data, "name") ?? "");
    final emailC = TextEditingController(text: email);
    final collegeC = TextEditingController(
        text: _read(data, "college") ?? _read(data, "collegeName") ?? "");
    final courseC = TextEditingController(text: _read(data, "course") ?? "");
    final phoneC = TextEditingController(text: _read(data, "mobile") ?? "");
    final percentC =
    TextEditingController(text: _read(data, "percentage") ?? "");
    final incomeC =
    TextEditingController(text: _read(data, "annualIncome") ?? "");

    String? category = _read(data, "category");
    final List<String> categoryItems = [..._categoryOptions];
    if (category != null && !categoryItems.contains(category)) {
      categoryItems.add(category);
    }

    bool saving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> save() async {
              final String name = nameC.text.trim();

              if (name.isEmpty) {
                setDialogState(() => errorText = "Name cannot be empty");
                return;
              }

              double? percentage;
              final pText = percentC.text.trim();
              if (pText.isNotEmpty) {
                percentage = double.tryParse(pText);
                if (percentage == null || percentage < 0 || percentage > 100) {
                  setDialogState(
                          () => errorText = "Enter a valid percentage (0 – 100)");
                  return;
                }
              }

              double? income;
              final iText = incomeC.text.trim();
              if (iText.isNotEmpty) {
                income = double.tryParse(iText);
                if (income == null || income < 0) {
                  setDialogState(
                          () => errorText = "Enter a valid annual income");
                  return;
                }
              }

              setDialogState(() {
                errorText = null;
                saving = true;
              });

              final bool ok = await _updateProfile(
                uid: uid,
                fields: {
                  "name": name,
                  "college": collegeC.text.trim(),
                  "course": courseC.text.trim(),
                  "mobile": phoneC.text.trim(),
                  if (category != null) "category": category,
                  "percentage":
                  percentage ?? FieldValue.delete(),
                  "annualIncome": income ?? FieldValue.delete(),
                },
              );

              if (!ok) {
                if (ctx.mounted) setDialogState(() => saving = false);
                return;
              }

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }

            return Dialog(
              backgroundColor: AppColors.card,
              insetPadding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 12, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.edit_rounded,
                                size: 19, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Edit Profile",
                              style: AppTextStyles.title.copyWith(fontSize: 18),
                            ),
                          ),
                          IconButton(
                            onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),

                    // Form
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
                        child: Column(
                          children: [
                            TextField(
                              controller: nameC,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDecoration(
                                  "Full Name", Icons.person_rounded),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: emailC,
                              enabled: false,
                              decoration: _inputDecoration(
                                "Email",
                                Icons.email_rounded,
                                helper: "Email can't be changed here",
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: phoneC,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDecoration(
                                  "Phone", Icons.phone_rounded),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: collegeC,
                              decoration: _inputDecoration(
                                  "College", Icons.school_rounded),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: courseC,
                              decoration: _inputDecoration(
                                  "Course", Icons.menu_book_rounded),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: category,
                              isExpanded: true,
                              decoration: _inputDecoration(
                                  "Category", Icons.category_rounded),
                              items: categoryItems
                                  .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => category = v),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: percentC,
                                    keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                    decoration: _inputDecoration(
                                        "Percentage", Icons.percent_rounded),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: incomeC,
                                    keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                    decoration: _inputDecoration(
                                        "Annual Income",
                                        Icons.currency_rupee_rounded),
                                  ),
                                ),
                              ],
                            ),
                            if (errorText != null) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  errorText!,
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding:
                                const EdgeInsets.symmetric(vertical: 15),
                                side: BorderSide(
                                  color:
                                  AppColors.textSecondary.withOpacity(0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: saving ? null : save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: saving
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                "Save Changes",
                                style: TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // UPDATE PROFILE
  // ==========================================================

  Future<bool> _updateProfile({
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        ...fields,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      _snack("Profile updated successfully!");
      return true;
    } catch (e) {
      _snack("Failed to update profile: $e");
      return false;
    }
  }
}

// ============================================================
// STAT CARD
// ============================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION CARD (groups rows under one heading)
// ============================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoRow> rows;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Row(
              children: [
                Icon(icon, size: 19, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.title.copyWith(fontSize: 15.5),
                ),
              ],
            ),
          ),
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 70,
                endIndent: 18,
                color: AppColors.textSecondary.withOpacity(0.10),
              ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ============================================================
// INFO ROW
// ============================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final bool empty = value == "Not added";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.subtitle.copyWith(
                    color: empty
                        ? AppColors.textSecondary.withOpacity(0.7)
                        : AppColors.textPrimary,
                    fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
                    fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}