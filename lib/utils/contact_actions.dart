import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// ====== INGA UNGA REAL DETAILS FILL PANNUNGA ======
class SupportContact {
  static const String phone = '+919876543210'; // call number (with +91)

  // WhatsApp number: country code + number, '+' / space / '-' VENDAAM.
  // Idhu WhatsApp-la register aana real number-a irukkanum.
  static const String whatsapp = '919876543210';

  static const String email = 'support@yourapp.com';
  static const String whatsappDefaultMessage =
      'Hello, I need help regarding scholarships.';
  static const String emailSubject = 'Scholarship App Support';
  static const String emailBody = 'Hello Support Team,\n\n';
}

enum ContactType { call, whatsapp, email }

class _ContactConfig {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String hint;
  final String buttonLabel;

  const _ContactConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.hint,
    required this.buttonLabel,
  });
}

_ContactConfig _configFor(ContactType type) {
  switch (type) {
    case ContactType.call:
      return const _ContactConfig(
        icon: Icons.call,
        color: Colors.green,
        title: 'Call Support',
        value: SupportContact.phone,
        hint: 'Mon - Sat, 9:00 AM to 6:00 PM',
        buttonLabel: 'Call Now',
      );
    case ContactType.whatsapp:
      return const _ContactConfig(
        icon: Icons.chat,
        color: Color(0xFF25D366),
        title: 'WhatsApp Support',
        value: '+${SupportContact.whatsapp}',
        hint: 'Unga message type pannunga, support number-ku chat open aagum',
        buttonLabel: 'Send on WhatsApp',
      );
    case ContactType.email:
      return const _ContactConfig(
        icon: Icons.email,
        color: Colors.redAccent,
        title: 'Email Support',
        value: SupportContact.email,
        hint: 'Reply 24 hours-kulla varum',
        buttonLabel: 'Send Email',
      );
  }
}

/// onTap: () => showContactSheet(context, ContactType.call)
Future<void> showContactSheet(BuildContext context, ContactType type) async {
  final cfg = _configFor(type);
  final msgController =
  TextEditingController(text: SupportContact.whatsappDefaultMessage);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: cfg.color.withOpacity(0.12),
                  child: Icon(cfg.icon, color: cfg.color, size: 30),
                ),
                const SizedBox(height: 12),
                Text(cfg.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(
                  cfg.value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: cfg.color),
                ),
                const SizedBox(height: 6),
                Text(cfg.hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600)),
                if (type == ContactType.whatsapp) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: msgController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Your message',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: cfg.value));
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(content: Text('Copied')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cfg.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Icon(cfg.icon, size: 18),
                        label: Text(cfg.buttonLabel),
                        onPressed: () => _launch(
                            sheetContext, type, cfg, msgController.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  msgController.dispose();
}

Future<bool> _open(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
  try {
    return await launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}

Future<void> _launch(BuildContext context, ContactType type,
    _ContactConfig cfg, String message) async {
  final messenger = ScaffoldMessenger.of(context);
  bool ok = false;

  switch (type) {
    case ContactType.call:
      ok = await _open(Uri(scheme: 'tel', path: SupportContact.phone));
      break;

    case ContactType.whatsapp:
      final text = Uri.encodeComponent(
          message.trim().isEmpty ? SupportContact.whatsappDefaultMessage : message.trim());
      final number = SupportContact.whatsapp;
      // 1) WhatsApp app-a direct-a, andha number-oda chat + message-oda
      ok = await _open(
        Uri.parse('whatsapp://send?phone=$number&text=$text'),
        mode: LaunchMode.externalApplication,
      );
      // 2) App illena wa.me link (browser -> WhatsApp)
      if (!ok) {
        ok = await _open(
          Uri.parse('https://wa.me/$number?text=$text'),
          mode: LaunchMode.externalApplication,
        );
      }
      break;

    case ContactType.email:
      ok = await _open(Uri.parse(
        'mailto:${SupportContact.email}'
            '?subject=${Uri.encodeComponent(SupportContact.emailSubject)}'
            '&body=${Uri.encodeComponent(SupportContact.emailBody)}',
      ));
      break;
  }

  if (ok) {
    if (context.mounted) Navigator.pop(context);
  } else {
    await Clipboard.setData(ClipboardData(text: cfg.value));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            'Indha device-la open panna mudiyala. ${cfg.value} copy aayiduchu.'),
      ),
    );
  }
}