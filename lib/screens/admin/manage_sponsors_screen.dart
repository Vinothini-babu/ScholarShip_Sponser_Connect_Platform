import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Admin: review, verify / reject and remove sponsors.
///
/// users/{sponsorUid}.verificationStatus : pending | verified | rejected
/// (sponsors that have no such field are old accounts = verified)
class ManageSponsorsScreen extends StatefulWidget {
  const ManageSponsorsScreen({super.key});

  @override
  State<ManageSponsorsScreen> createState() => _ManageSponsorsScreenState();
}

class _ManageSponsorsScreenState extends State<ManageSponsorsScreen> {
  // Same teal as the "Verify Sponsors" quick-action card on the dashboard.
  static const Color _theme = Colors.teal;
  static final Color _dark = Color.lerp(_theme, Colors.black, 0.45)!;

  String _filter = "All"; // All | Pending | Verified | Rejected
  String _q = "";
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _statusOf(Map<String, dynamic> d) =>
      (d["verificationStatus"] ?? "verified").toString().toLowerCase();

  static String _orgName(Map<String, dynamic> d) {
    for (final k in ["organizationName", "name", "college"]) {
      final v = d[k]?.toString().trim() ?? "";
      if (v.isNotEmpty) return v;
    }
    return "Unknown Sponsor";
  }

  Color _statusColor(String s) {
    switch (s) {
      case "verified":
        return AppColors.success;
      case "rejected":
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case "verified":
        return "VERIFIED";
      case "rejected":
        return "REJECTED";
      default:
        return "PENDING";
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .where("role", isEqualTo: "sponsor")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _shell(
              pending: 0,
              verified: 0,
              rejected: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Unable to load sponsors.\n\n${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return _shell(
              pending: 0,
              verified: 0,
              rejected: 0,
              child: const Center(
                child: CircularProgressIndicator(color: _theme),
              ),
            );
          }

          final all = snapshot.data!.docs;

          int pending = 0, verified = 0, rejected = 0;
          for (final d in all) {
            switch (_statusOf(d.data())) {
              case "pending":
                pending++;
                break;
              case "rejected":
                rejected++;
                break;
              default:
                verified++;
            }
          }

          final q = _q.trim().toLowerCase();

          // filter + search + sort (pending first)
          final shown = all.where((d) {
            final data = d.data();
            final s = _statusOf(data);
            if (_filter == "Pending" && s != "pending") return false;
            if (_filter == "Verified" && s != "verified") return false;
            if (_filter == "Rejected" && s != "rejected") return false;
            if (q.isNotEmpty) {
              final hay = [
                _orgName(data),
                (data["name"] ?? "").toString(),
                (data["email"] ?? "").toString(),
                (data["registrationNumber"] ?? "").toString(),
              ].join(" ").toLowerCase();
              if (!hay.contains(q)) return false;
            }
            return true;
          }).toList()
            ..sort((a, b) {
              int rank(String s) =>
                  s == "pending" ? 0 : (s == "rejected" ? 1 : 2);
              return rank(_statusOf(a.data())).compareTo(rank(_statusOf(b.data())));
            });

          return _shell(
            pending: pending,
            verified: verified,
            rejected: rejected,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  children: [
                    _searchBox(),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip("All", all.length, Icons.apps_rounded),
                        _chip("Pending", pending, Icons.hourglass_top_rounded),
                        _chip("Verified", verified, Icons.verified_rounded),
                        _chip("Rejected", rejected, Icons.cancel_rounded),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (pending > 0 && _filter == "All" && q.isEmpty)
                      _StaggerIn(
                        child: _pendingBanner(pending),
                      ),
                    if (shown.isEmpty)
                      _emptyState()
                    else
                      for (var i = 0; i < shown.length; i++)
                        _StaggerIn(
                          key: ValueKey("$_filter-${shown[i].id}"),
                          delay: Duration(milliseconds: 70 * (i > 6 ? 6 : i)),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _HoverLift(
                              child: _buildSponsorCard(
                                  context, shown[i].id, shown[i].data()),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // THEMED HEADER (same look as Call Students / Call Sponsors)
  // ============================================================

  Widget _shell({
    required int pending,
    required int verified,
    required int rejected,
    required Widget child,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_dark, _theme],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: _theme.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 940),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.elasticOut,
                            builder: (context, v, c) => Transform.scale(
                                scale: v.clamp(0.0, 1.3).toDouble(), child: c),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_rounded,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Verify Sponsors",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                _LivePill(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              icon: Icons.hourglass_top_rounded,
                              label: "Pending",
                              value: pending,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatBox(
                              icon: Icons.verified_rounded,
                              label: "Verified",
                              value: verified,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatBox(
                              icon: Icons.cancel_rounded,
                              label: "Rejected",
                              value: rejected,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _searchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _theme.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _theme.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          hintText: "Search by organisation, email or reg. no.",
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, color: _theme),
          suffixIcon: _q.isEmpty
              ? null
              : IconButton(
            icon: Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 19),
            onPressed: () {
              _search.clear();
              setState(() => _q = "");
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _chip(String label, int count, IconData icon) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [_dark, _theme])
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _theme : Colors.black.withOpacity(0.1),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: _theme.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15, color: selected ? Colors.white : _theme),
            const SizedBox(width: 6),
            Text(
              "$label ($count)",
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingBanner(int n) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          _Pulse(
            builder: (context, t) => Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withOpacity(0.25 + 0.4 * t),
                    blurRadius: 6 + 10 * t,
                    spreadRadius: 1 + 2 * t,
                  ),
                ],
              ),
              child: const Icon(Icons.pending_actions_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "$n sponsor${n == 1 ? '' : 's'} awaiting verification. "
                  "Check the proof document, then verify or reject.",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Center(
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, v, c) => Transform.scale(
                  scale: v.clamp(0.0, 1.3).toDouble(), child: c),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _theme.withOpacity(0.12),
                ),
                child: const Icon(Icons.business_outlined,
                    size: 46, color: _theme),
              ),
            ),
            const SizedBox(height: 16),
            Text("No Sponsors Found",
                style: AppTextStyles.title.copyWith(fontSize: 18)),
            const SizedBox(height: 5),
            Text(
              _q.isNotEmpty
                  ? "Nothing matches \"$_q\"."
                  : (_filter == "All"
                  ? "Registered sponsors will appear here."
                  : "No ${_filter.toLowerCase()} sponsors."),
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SPONSOR CARD
  // ============================================================

  Widget _buildSponsorCard(
      BuildContext context, String id, Map<String, dynamic> data) {
    final status = _statusOf(data);
    final color = _statusColor(status);

    final org = _orgName(data);
    final contact = (data["name"] ?? "").toString().trim();
    final email = (data["email"] ?? "").toString().trim();
    final mobile = (data["mobile"] ?? "").toString().trim();
    final regNo = (data["registrationNumber"] ?? "").toString().trim();
    final proof = (data["proofDocumentUrl"] ?? "").toString().trim();
    final reason = (data["rejectionReason"] ?? "").toString().trim();

    Widget card(double glow) => Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: status == "pending"
                ? AppColors.warning.withOpacity(0.12 + 0.22 * glow)
                : _theme.withOpacity(0.10),
            blurRadius: status == "pending" ? 12 + 12 * glow : 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_theme, _dark],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _theme.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        org.isNotEmpty ? org[0].toUpperCase() : "?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      org,
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status == "verified"
                              ? Icons.verified_rounded
                              : status == "rejected"
                              ? Icons.cancel_rounded
                              : Icons.hourglass_top_rounded,
                          size: 13,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _infoRow(
                  Icons.person_rounded, contact, "Contact person not available",
                  show: contact.isNotEmpty && contact != org),
              _infoRow(Icons.email_rounded, email, "Email not available"),
              _infoRow(Icons.phone_rounded, mobile, "",
                  show: mobile.isNotEmpty),
              _infoRow(Icons.badge_rounded, "Reg. No: $regNo", "",
                  show: regNo.isNotEmpty),

              if (proof.isNotEmpty) ...[
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openUrl(context, proof),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _theme.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _theme.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.description_rounded,
                            size: 16, color: _theme),
                        SizedBox(width: 8),
                        Text(
                          "View proof document",
                          style: TextStyle(
                            color: _theme,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (status == "rejected" && reason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Reason: $reason",
                    style:
                    TextStyle(fontSize: 12.5, color: AppColors.error),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // -------- actions --------
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showSponsorDetails(context, data),
                    icon: const Icon(Icons.visibility_rounded,
                        size: 17, color: _theme),
                    label: const Text("View",
                        style: TextStyle(color: _theme)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      side: const BorderSide(color: _theme, width: 1.4),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (status != "verified")
                    ElevatedButton.icon(
                      onPressed: () => _verify(context, id, org),
                      icon: const Icon(Icons.verified_rounded, size: 17),
                      label: const Text("Verify"),
                      style: _filled(AppColors.success),
                    ),
                  if (status != "rejected")
                    ElevatedButton.icon(
                      onPressed: () => _reject(context, id, org),
                      icon: const Icon(Icons.block_rounded, size: 17),
                      label: const Text("Reject"),
                      style: _filled(AppColors.warning),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => _removeSponsor(context, id, org),
                    icon: const Icon(Icons.delete_rounded, size: 17),
                    label: const Text("Remove"),
                    style: _filled(AppColors.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // pending cards softly pulse so the admin notices them
    if (status == "pending") {
      return _Pulse(
        duration: const Duration(milliseconds: 1600),
        builder: (context, t) => card(t),
      );
    }
    return card(0);
  }

  ButtonStyle _filled(Color c) => ElevatedButton.styleFrom(
    minimumSize: const Size(0, 42),
    backgroundColor: c,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _infoRow(IconData icon, String value, String fallback,
      {bool show = true}) {
    if (!show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _theme.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: _theme),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : fallback,
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _openUrl(BuildContext context, String url) async {
    var link = url.trim();
    Uri? uri;

    final isWindowsPath = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(link);

    if (isWindowsPath) {
      // Local file path (e.g. D:/folder/file.pdf) - works only on the
      // machine that has the file. Real fix: upload proof to Cloudinary.
      uri = Uri.file(link, windows: true);
    } else if (link.startsWith('file://')) {
      uri = Uri.tryParse(link);
    } else {
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        link = 'https://$link';
      }
      uri = Uri.tryParse(link);
      if (uri != null && !uri.host.contains('.')) uri = null;
    }

    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid document link: $url")),
      );
      return;
    }

    try {
      var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open: $url")),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open the document ($e)")),
      );
    }
  }

  /// users/{id} is what the app reads; sponsors/{id} is a mirror written at
  /// signup, so we keep it in sync when it exists.
  Future<void> _setStatus(String id, Map<String, dynamic> fields) async {
    final db = FirebaseFirestore.instance;
    await db.collection("users").doc(id).update(fields);
    try {
      final mirror = db.collection("sponsors").doc(id);
      if ((await mirror.get()).exists) {
        await mirror.update(fields);
      }
    } catch (_) {
      // mirror is optional - ignore
    }
  }

  Future<void> _verify(BuildContext context, String id, String org) async {
    try {
      await _setStatus(id, {
        "verificationStatus": "verified",
        "rejectionReason": FieldValue.delete(),
        "verifiedAt": FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$org verified \u2714")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to verify: $e")),
      );
    }
  }

  Future<void> _reject(BuildContext context, String id, String org) async {
    final ctrl = TextEditingController();
    String? error;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("Reject sponsor"),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tell $org why the account is being rejected."),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "e.g. Registration number could not be verified",
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().length < 5) {
                  setS(() => error = "Please enter a reason (min 5 characters)");
                  return;
                }
                Navigator.pop(dialogCtx, true);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 42),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text("Reject"),
            ),
          ],
        ),
      ),
    );

    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;

    try {
      await _setStatus(id, {
        "verificationStatus": "rejected",
        "rejectionReason": reason,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$org rejected")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to reject: $e")),
      );
    }
  }

  void _showSponsorDetails(BuildContext context, Map<String, dynamic> d) {
    String v(String k) => (d[k] ?? "").toString().trim();

    final rows = <MapEntry<String, String>>[
      MapEntry("Organization", _orgName(d)),
      MapEntry("Contact person", v("name")),
      MapEntry("Email", v("email")),
      MapEntry("Mobile", v("mobile")),
      MapEntry("Registration no.", v("registrationNumber")),
      MapEntry("State", v("state")),
      MapEntry("District", v("district")),
      MapEntry("Verification", _statusLabel(_statusOf(d))),
      if (v("rejectionReason").isNotEmpty)
        MapEntry("Rejection reason", v("rejectionReason")),
    ].where((e) => e.value.isNotEmpty).toList();

    final proof = v("proofDocumentUrl");

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Sponsor Details"),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(e.value,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (proof.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openUrl(context, proof),
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: const Text("View proof document"),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSponsor(
      BuildContext context, String documentId, String sponsorName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Remove Sponsor"),
        content: Text("Are you sure you want to remove $sponsorName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(documentId)
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$sponsorName removed successfully")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove sponsor: $e")),
      );
    }
  }
}


// ================================================================
// THEMED HELPERS (header stats, live pill, animations)
// ================================================================

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  const _StatBox(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.toDouble()),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  v.round().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.3, end: 1).animate(_c),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFF4ADE80), shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        Text("Live verification",
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 12.5)),
      ],
    );
  }
}

/// Fade + slide-up entrance after [delay].
class _StaggerIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _StaggerIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn> {
  bool _go = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) setState(() => _go = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _go ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _go ? Offset.zero : const Offset(0, 0.10),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Looping 0..1..0 value for pulsing glows.
class _Pulse extends StatefulWidget {
  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;
  const _Pulse({
    required this.builder,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          widget.builder(context, Curves.easeInOut.transform(_c.value)),
    );
  }
}

/// Lifts slightly when the mouse hovers (desktop).
class _HoverLift extends StatefulWidget {
  final Widget child;
  const _HoverLift({required this.child});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        offset: _hover ? const Offset(0, -0.012) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}