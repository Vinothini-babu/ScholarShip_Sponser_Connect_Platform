// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';

/// Admin "Call Students" / "Call Sponsors" directory.
///
///   ContactDirectoryScreen(
///     role: "student" | "sponsor",
///     title: "Call Students",
///     color: Colors.indigo,
///     icon: Icons.people_alt_rounded,
///   )
class ContactDirectoryScreen extends StatefulWidget {
  final String role;
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

// ---------------------------------------------------------
// data helpers
// ---------------------------------------------------------

class _Person {
  final String id;
  final Map<String, dynamic> data;
  final String name;
  final String email;
  final String phone;
  final String org; // college (student) / organisation (sponsor)
  final String sub; // course (student) / org type (sponsor)
  final String year;
  final String location;
  final bool awarded;

  _Person({
    required this.id,
    required this.data,
    required this.name,
    required this.email,
    required this.phone,
    required this.org,
    required this.sub,
    required this.year,
    required this.location,
    required this.awarded,
  });

  bool get hasPhone => phone.trim().isNotEmpty;
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : "?";
}

String _pick(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return "";
}

_Person _toPerson(String id, Map<String, dynamic> m, bool isStudent) {
  final city = _pick(m, ["city", "district"]);
  final state = _pick(m, ["state"]);
  return _Person(
    id: id,
    data: m,
    name: (isStudent
        ? _pick(m, ["name", "fullName"])
        : _pick(m, ["organizationName", "name"]))
        .isEmpty
        ? (isStudent ? "Unknown Student" : "Unknown Sponsor")
        : (isStudent
        ? _pick(m, ["name", "fullName"])
        : _pick(m, ["organizationName", "name"])),
    email: _pick(m, ["email"]),
    phone: _pick(m, [
      "phone", "phoneNumber", "mobile", "mobileNumber",
      "contact", "contactNumber"
    ]),
    // student: college  |  sponsor: contact person (when different from org)
    org: isStudent
        ? _pick(m, ["college", "collegeName", "institution", "institute"])
        : (_pick(m, ["organizationName"]).isEmpty ||
        _pick(m, ["name"]) == _pick(m, ["organizationName"])
        ? ""
        : _pick(m, ["name"])),
    sub: isStudent
        ? _pick(m, ["course", "branch", "department"])
        : _pick(m, ["organizationType", "orgType", "sponsorType", "category"]),
    year: isStudent ? _pick(m, ["year", "yearOfStudy"]) : "",
    location: [city, state].where((e) => e.isNotEmpty).join(", "),
    awarded: m["isAwarded"] == true,
  );
}

String _e164(String p) {
  final d = p.replaceAll(RegExp(r"[^0-9]"), "");
  if (d.length == 10) return "+91$d";
  return "+$d";
}

Future<bool> _try(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
  try {
    return await launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}

void _toast(BuildContext c, String msg) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg),
    ),
  );
}

Future<void> _copy(BuildContext c, String text, {String? msg}) async {
  await Clipboard.setData(ClipboardData(text: text));
  _toast(c, msg ?? "Copied: $text");
}

Future<void> _doCall(BuildContext c, _Person p) async {
  if (!p.hasPhone) return;
  final ok = await _try(Uri(scheme: "tel", path: _e164(p.phone)));
  if (!ok) {
    await Clipboard.setData(ClipboardData(text: p.phone));
    _toast(c, "Couldn't open the dialer on this device. "
        "${p.phone} copied to clipboard.");
  }
}

Future<void> _doWhatsApp(BuildContext c, _Person p, {String? message}) async {
  if (!p.hasPhone) return;
  final number = _e164(p.phone).substring(1);
  final text = Uri.encodeComponent(
      (message == null || message.trim().isEmpty)
          ? "Hello ${p.name}, this is the Scholarship Platform admin team."
          : message.trim());
  var ok = await _try(
    Uri.parse("whatsapp://send?phone=$number&text=$text"),
    mode: LaunchMode.externalApplication,
  );
  if (!ok) {
    ok = await _try(
      Uri.parse("https://wa.me/$number?text=$text"),
      mode: LaunchMode.externalApplication,
    );
  }
  if (!ok) {
    await Clipboard.setData(ClipboardData(text: p.phone));
    _toast(c, "Couldn't open WhatsApp. ${p.phone} copied to clipboard.");
  }
}

Future<void> _doEmail(BuildContext c, _Person p) async {
  if (p.email.isEmpty) return;
  final ok = await _try(Uri.parse("mailto:${p.email}"));
  if (!ok) {
    await Clipboard.setData(ClipboardData(text: p.email));
    _toast(c, "Couldn't open a mail app. ${p.email} copied to clipboard.");
  }
}

// ---------------------------------------------------------
// screen
// ---------------------------------------------------------

class _ContactDirectoryScreenState extends State<ContactDirectoryScreen> {
  final TextEditingController _search = TextEditingController();
  String _q = "";
  String _filter = "All"; // All | With phone | No phone
  String _type = "All"; // sponsor organisation type

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
  FirebaseFirestore.instance.collection("users").snapshots();

  bool get _isStudent => widget.role.toLowerCase() == "student";

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Shell(
              color: widget.color,
              icon: widget.icon,
              title: widget.title,
              total: 0,
              withPhone: 0,
              noPhone: 0,
              child: _Message(
                icon: Icons.error_outline_rounded,
                title: "Couldn't load contacts",
                sub: "${snap.error}",
              ),
            );
          }
          if (!snap.hasData) {
            return _Shell(
              color: widget.color,
              icon: widget.icon,
              title: widget.title,
              total: 0,
              withPhone: 0,
              noPhone: 0,
              child: Center(
                child: CircularProgressIndicator(color: widget.color),
              ),
            );
          }

          final all = snap.data!.docs
              .where((d) =>
          (d.data()["role"] ?? "").toString().trim().toLowerCase() ==
              widget.role.toLowerCase())
              .map((d) => _toPerson(d.id, d.data(), _isStudent))
              .toList()
            ..sort((a, b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          final withPhone = all.where((p) => p.hasPhone).length;
          final noPhone = all.length - withPhone;

          final types = <String>{
            for (final p in all)
              if (p.sub.isNotEmpty && !_isStudent) p.sub
          }.toList()
            ..sort();

          final q = _q.trim().toLowerCase();
          final list = all.where((p) {
            if (_filter == "With phone" && !p.hasPhone) return false;
            if (_filter == "No phone" && p.hasPhone) return false;
            if (_type != "All" && p.sub != _type) return false;
            if (q.isEmpty) return true;
            return p.name.toLowerCase().contains(q) ||
                p.email.toLowerCase().contains(q) ||
                p.phone.toLowerCase().contains(q) ||
                p.org.toLowerCase().contains(q);
          }).toList();

          return _Shell(
            color: widget.color,
            icon: widget.icon,
            title: widget.title,
            total: all.length,
            withPhone: withPhone,
            noPhone: noPhone,
            child: Column(
              children: [
                // search
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _search,
                          onChanged: (v) => setState(() => _q = v),
                          decoration: InputDecoration(
                            hintText: "Search by name, phone, email or "
                                "${_isStudent ? 'college' : 'contact person'}",
                            prefixIcon: Icon(Icons.search_rounded,
                                color: widget.color),
                            suffixIcon: _q.isEmpty
                                ? null
                                : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _search.clear();
                                _q = "";
                              }),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // filter chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip("All", all.length, _filter == "All",
                                    () => setState(() => _filter = "All")),
                            _chip("With phone", withPhone,
                                _filter == "With phone",
                                    () => setState(() => _filter = "With phone")),
                            _chip("No phone", noPhone, _filter == "No phone",
                                    () => setState(() => _filter = "No phone")),
                            for (final t in types)
                              _chip(
                                t,
                                all.where((p) => p.sub == t).length,
                                _type == t,
                                    () => setState(
                                        () => _type = _type == t ? "All" : t),
                                icon: Icons.label_rounded,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // list
                Expanded(
                  child: list.isEmpty
                      ? _Message(
                    icon: Icons.person_search_rounded,
                    title: all.isEmpty
                        ? "No ${_isStudent ? 'students' : 'sponsors'} registered yet"
                        : "No matching results",
                    sub: all.isEmpty
                        ? "New registrations appear here live."
                        : "Try a different name, number or filter.",
                  )
                      : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final p = list[i];
                          return _Reveal(
                            key: ValueKey("rv_${p.id}"),
                            delay: Duration(
                                milliseconds: 45 * math.min(i, 10)),
                            child: _PersonCard(
                              person: p,
                              color: widget.color,
                              isStudent: _isStudent,
                              onOpen: () => _openDetail(p),
                            ),
                          );
                        },
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

  Widget _chip(String label, int count, bool selected, VoidCallback onTap,
      {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? widget.color : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: selected
                    ? widget.color
                    : Colors.black.withOpacity(0.08)),
            boxShadow: selected
                ? [
              BoxShadow(
                color: widget.color.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14, color: selected ? Colors.white : widget.color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.25)
                      : widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : widget.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(_Person p) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Contact",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Material(
                  color: AppColors.background,
                  child: _PersonDetail(
                    person: p,
                    color: widget.color,
                    isStudent: _isStudent,
                    dialogContext: dialogContext,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// header shell (gradient header + live badge + animated stats)
// ---------------------------------------------------------

class _Shell extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final int total;
  final int withPhone;
  final int noPhone;
  final Widget child;

  const _Shell({
    required this.color,
    required this.icon,
    required this.title,
    required this.total,
    required this.withPhone,
    required this.noPhone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(color, Colors.black, 0.45)!;

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [dark, color],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
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
                            builder: (context, v, c) =>
                                Transform.scale(scale: v, child: c),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const _LivePill(),
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
                                  icon: Icons.groups_rounded,
                                  label: "Total",
                                  value: total)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _StatBox(
                                  icon: Icons.phone_in_talk_rounded,
                                  label: "Reachable",
                                  value: withPhone)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _StatBox(
                                  icon: Icons.phone_disabled_rounded,
                                  label: "No phone",
                                  value: noPhone)),
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
}

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
        Text("Live directory",
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 12.5)),
      ],
    );
  }
}

// ---------------------------------------------------------
// person card
// ---------------------------------------------------------

class _PersonCard extends StatefulWidget {
  final _Person person;
  final Color color;
  final bool isStudent;
  final VoidCallback onOpen;

  const _PersonCard({
    required this.person,
    required this.color,
    required this.isStudent,
    required this.onOpen,
  });

  @override
  State<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<_PersonCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final c = widget.color;

    final subtitle = [p.sub, p.org].where((e) => e.isNotEmpty).join("  •  ");

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
            ),
            if (p.awarded) ...[
              const SizedBox(width: 8),
              _Badge("AWARDED", AppColors.success, Icons.workspace_premium_rounded),
            ],
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (p.email.isNotEmpty)
              _meta(Icons.alternate_email_rounded, p.email),
            _meta(Icons.phone_rounded,
                p.hasPhone ? p.phone : "No phone number",
                muted: !p.hasPhone),
          ],
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.hasPhone) ...[
          _RoundAction(
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
            tooltip: "WhatsApp",
            onTap: () => _doWhatsApp(context, p),
          ),
          const SizedBox(width: 8),
          _RoundAction(
            icon: Icons.copy_rounded,
            color: AppColors.textSecondary,
            tooltip: "Copy number",
            onTap: () => _copy(context, p.phone),
          ),
          const SizedBox(width: 10),
        ],
        ElevatedButton.icon(
          onPressed: p.hasPhone ? () => _doCall(context, p) : null,
          icon: const Icon(Icons.call_rounded, size: 18),
          label: const Text("Call",
              style: TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 42),
            backgroundColor: const Color(0xFFFF6B4A),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.black12,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _hover ? c.withOpacity(0.5) : Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: _hover ? c.withOpacity(0.18) : Colors.black.withOpacity(0.05),
              blurRadius: _hover ? 22 : 10,
              offset: Offset(0, _hover ? 10 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, cons) {
                  final narrow = cons.maxWidth < 620;
                  final avatar = _Avatar(initial: p.initial, color: c);
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            avatar,
                            const SizedBox(width: 14),
                            Expanded(child: info),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                            alignment: Alignment.centerRight, child: actions),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      avatar,
                      const SizedBox(width: 16),
                      Expanded(child: info),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, {bool muted = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon,
          size: 14,
          color: muted ? AppColors.textSecondary.withOpacity(0.6) : widget.color),
      const SizedBox(width: 6),
      Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
          color: muted ? AppColors.textSecondary : AppColors.textPrimary,
        ),
      ),
    ],
  );
}

class _Avatar extends StatelessWidget {
  final String initial;
  final Color color;
  final double size;
  const _Avatar({required this.initial, required this.color, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.75), Color.lerp(color, Colors.black, 0.35)!],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _Badge(this.text, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// detail dialog
// ---------------------------------------------------------

class _PersonDetail extends StatefulWidget {
  final _Person person;
  final Color color;
  final bool isStudent;
  final BuildContext dialogContext;

  const _PersonDetail({
    required this.person,
    required this.color,
    required this.isStudent,
    required this.dialogContext,
  });

  @override
  State<_PersonDetail> createState() => _PersonDetailState();
}

class _PersonDetailState extends State<_PersonDetail> {
  late final TextEditingController _msg = TextEditingController(
    text: "Hello ${widget.person.name}, this is the Scholarship Platform "
        "admin team.",
  );

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final c = widget.color;
    final dark = Color.lerp(c, Colors.black, 0.45)!;

    final rows = <(IconData, String, String)>[
      (Icons.phone_rounded, "Phone", p.phone),
      (Icons.alternate_email_rounded, "Email", p.email),
      (
      widget.isStudent ? Icons.school_rounded : Icons.person_rounded,
      widget.isStudent ? "College" : "Contact person",
      p.org
      ),
      (
      widget.isStudent ? Icons.menu_book_rounded : Icons.category_rounded,
      widget.isStudent ? "Course" : "Type",
      p.sub
      ),
      if (widget.isStudent) (Icons.timeline_rounded, "Year", p.year),
      (Icons.location_on_rounded, "Location", p.location),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 12, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [dark, c],
            ),
          ),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Text(
                    p.initial,
                    style: TextStyle(
                        color: c, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(widget.isStudent ? "Student" : "Sponsor",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13)),
                    if (p.awarded) ...[
                      const SizedBox(height: 8),
                      _Badge("AWARDED", AppColors.success,
                          Icons.workspace_premium_rounded),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(widget.dialogContext),
                icon: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.85)),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      for (final r in rows)
                        if (r.$3.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(r.$1, size: 18, color: c),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 82,
                                  child: Text(r.$2,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary)),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    r.$3,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
                if (p.hasPhone) ...[
                  const SizedBox(height: 16),
                  Text("WHATSAPP MESSAGE",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: c,
                      )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _msg,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: Colors.black.withOpacity(0.08)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            border:
            Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (p.email.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _doEmail(context, p),
                  icon: const Icon(Icons.email_rounded, size: 17),
                  label: const Text("Email"),
                  style: _outlined(c),
                ),
              if (p.hasPhone)
                OutlinedButton.icon(
                  onPressed: () => _copy(context, p.phone),
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text("Copy"),
                  style: _outlined(c),
                ),
              if (p.hasPhone)
                ElevatedButton.icon(
                  onPressed: () =>
                      _doWhatsApp(context, p, message: _msg.text),
                  icon: const Icon(Icons.chat_rounded, size: 17),
                  label: const Text("WhatsApp"),
                  style: _filled(const Color(0xFF25D366)),
                ),
              ElevatedButton.icon(
                onPressed: p.hasPhone ? () => _doCall(context, p) : null,
                icon: const Icon(Icons.call_rounded, size: 17),
                label: const Text("Call"),
                style: _filled(const Color(0xFFFF6B4A)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ButtonStyle _outlined(Color c) => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    foregroundColor: c,
    side: BorderSide(color: c.withOpacity(0.5)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  ButtonStyle _filled(Color c) => ElevatedButton.styleFrom(
    minimumSize: const Size(0, 44),
    backgroundColor: c,
    foregroundColor: Colors.white,
    disabledBackgroundColor: Colors.black12,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

// ---------------------------------------------------------
// small helpers
// ---------------------------------------------------------

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _Message({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: _Reveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
                child:
                Icon(icon, size: 38, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// fade + slide-up entrance
class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _Reveal({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
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
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _go ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}