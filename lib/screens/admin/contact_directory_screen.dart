// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

const Color _navy = Color(0xFF1E3358);
const Color _coral = Color(0xFFEF6343);

/// Firestore la phone number entha field name la irundhaalum pick pannum.
const List<String> _phoneKeys = [
  "phone",
  "phoneNumber",
  "mobile",
  "mobileNumber",
  "contact",
  "contactNumber",
];

String _firstNonEmpty(List<dynamic> values, [String fallback = ""]) {
  for (final v in values) {
    final s = v?.toString().trim() ?? "";
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

String _phoneOf(Map<String, dynamic> data) =>
    _firstNonEmpty(_phoneKeys.map((k) => data[k]).toList());

// ============================================================
// SCREEN  (role: "student" or "sponsor")
// ============================================================

class ContactDirectoryScreen extends StatefulWidget {
  final String role; // "student" / "sponsor"
  final String title;
  final Color color;
  final IconData icon;

  const ContactDirectoryScreen({
    super.key,
    required this.role,
    required this.title,
    required this.color,
    required this.icon,
  });

  @override
  State<ContactDirectoryScreen> createState() => _ContactDirectoryScreenState();
}

class _ContactDirectoryScreenState extends State<ContactDirectoryScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  final TextEditingController _search = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    // live stream: Firestore la data maarina udane screen um maarum
    _stream = FirebaseFirestore.instance.collection("users").snapshots();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isSponsor => widget.role == "sponsor";

  String _nameOf(Map<String, dynamic> d) {
    if (_isSponsor) {
      return _firstNonEmpty(
        [d["organizationName"], d["name"]],
        "Unknown Sponsor",
      );
    }
    return _firstNonEmpty([d["name"], d["fullName"]], "Unknown Student");
  }

  String _subtitleOf(Map<String, dynamic> d) {
    if (_isSponsor) {
      final org = _firstNonEmpty([d["organizationName"]]);
      final person = _firstNonEmpty([d["name"]]);
      if (org.isNotEmpty && person.isNotEmpty && org != person) return person;
    }
    return _firstNonEmpty([d["email"]], "");
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: "tel", path: cleaned);

    try {
      if (await canLaunchUrl(uri) && await launchUrl(uri)) return;
    } catch (e) {
      debugPrint("Call error: $e");
    }

    // Windows / web la call support illa na number ah copy pannidum
    await Clipboard.setData(ClipboardData(text: cleaned));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("Call not supported here. Number copied: $cleaned"),
      ),
    );
  }

  Future<void> _copy(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text("Copied $phone"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snap) {
            final loading =
                snap.connectionState == ConnectionState.waiting && !snap.hasData;

            final all = (snap.data?.docs ?? const [])
                .where((d) =>
            (d.data()["role"]?.toString().trim().toLowerCase() ?? "") ==
                widget.role)
                .toList()
              ..sort((a, b) => _nameOf(a.data())
                  .toLowerCase()
                  .compareTo(_nameOf(b.data()).toLowerCase()));

            final q = _query.trim().toLowerCase();
            final list = q.isEmpty
                ? all
                : all.where((d) {
              final data = d.data();
              return _nameOf(data).toLowerCase().contains(q) ||
                  _phoneOf(data).contains(q) ||
                  _subtitleOf(data).toLowerCase().contains(q);
            }).toList();

            return Column(
              children: [
                _header(all.length),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: "Search by name, phone or email",
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : snap.hasError
                      ? const Center(child: Text("Something went wrong"))
                      : list.isEmpty
                      ? Center(
                    child: Text(
                      "No ${widget.title.toLowerCase()} found",
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _contactCard(list[i].data()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color.lerp(_navy, widget.color, 0.35)!],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$total registered • live",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(Map<String, dynamic> data) {
    final name = _nameOf(data);
    final sub = _subtitleOf(data);
    final phone = _phoneOf(data);
    final hasPhone = phone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: widget.color.withOpacity(0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone_rounded,
                      size: 13,
                      color: hasPhone ? widget.color : Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasPhone ? phone : "No phone number",
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: hasPhone ? _navy : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasPhone) ...[
            IconButton(
              tooltip: "Copy number",
              onPressed: () => _copy(phone),
              icon: const Icon(Icons.copy_rounded, size: 19),
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: () => _call(phone),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text("Call"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}