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
  String _filter = "All"; // All | Pending | Verified | Rejected

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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Manage Sponsors",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .where("role", isEqualTo: "sponsor")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
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
            );
          }

          final all = snapshot.data?.docs ?? [];

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

          // filter + sort (pending first)
          final shown = all.where((d) {
            final s = _statusOf(d.data());
            if (_filter == "Pending") return s == "pending";
            if (_filter == "Verified") return s == "verified";
            if (_filter == "Rejected") return s == "rejected";
            return true;
          }).toList()
            ..sort((a, b) {
              int rank(String s) => s == "pending" ? 0 : (s == "rejected" ? 1 : 2);
              return rank(_statusOf(a.data())).compareTo(rank(_statusOf(b.data())));
            });

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                "Registered Sponsors",
                style: AppTextStyles.title.copyWith(
                  fontSize: 22,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "${all.length} sponsors registered"
                    "${pending > 0 ? "  •  $pending awaiting verification" : ""}",
                style: AppTextStyles.subtitle.copyWith(
                  color: pending > 0
                      ? AppColors.warning
                      : AppColors.textSecondary,
                  fontWeight: pending > 0 ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 16),

              // -------- filter chips --------
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip("All", all.length),
                  _chip("Pending", pending),
                  _chip("Verified", verified),
                  _chip("Rejected", rejected),
                ],
              ),
              const SizedBox(height: 20),

              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 55, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text("No Sponsors Found",
                            style: AppTextStyles.title.copyWith(fontSize: 18)),
                        const SizedBox(height: 5),
                        Text(
                          _filter == "All"
                              ? "Registered sponsors will appear here."
                              : "No ${_filter.toLowerCase()} sponsors.",
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...shown.map(
                      (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildSponsorCard(context, doc.id, doc.data()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, int count) {
    final selected = _filter == label;
    return ChoiceChip(
      label: Text("$label ($count)"),
      selected: selected,
      onSelected: (_) => setState(() => _filter = label),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.primary : Colors.black.withOpacity(0.1),
      ),
      showCheckmark: false,
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == "pending"
              ? color.withOpacity(0.5)
              : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    org.isNotEmpty ? org[0].toUpperCase() : "?",
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.primary,
                      fontSize: 18,
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
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
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

          _infoRow(Icons.person_rounded, contact, "Contact person not available",
              show: contact.isNotEmpty && contact != org),
          _infoRow(Icons.email_rounded, email, "Email not available"),
          _infoRow(Icons.phone_rounded, mobile, "", show: mobile.isNotEmpty),
          _infoRow(Icons.badge_rounded, "Reg. No: $regNo", "",
              show: regNo.isNotEmpty),

          if (proof.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _openUrl(context, proof),
              icon: const Icon(Icons.description_rounded, size: 16),
              label: const Text("View proof document"),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
            ),
          ],

          if (status == "rejected" && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Reason: $reason",
                style: TextStyle(fontSize: 12.5, color: AppColors.error),
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
                icon: Icon(Icons.visibility_rounded,
                    size: 17, color: AppColors.primary),
                label: Text("View", style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  side: BorderSide(color: AppColors.primary, width: 1.4),
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
    );
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
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
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