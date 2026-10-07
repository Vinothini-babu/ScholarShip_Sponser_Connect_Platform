import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// NOTE: put this file in the SAME folder as status_timeline.dart and keep
// these two imports identical to the ones in status_timeline.dart.
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Sponsor-side "Scholarship Payment" card.
///
/// Usage (inside the sponsor's application_details_screen.dart, e.g. below
/// the Document Verification / Evaluation Score section):
///
///   SponsorPaymentCard(
///     applicationId: widget.applicationId,   // your existing variable
///     defaultAmount: data['amount']?.toString(),
///   ),
///
/// It only shows once the application is Approved. Data is stored at
/// applications/{id}.payment = {
///   status: "Paid" | "Received", amount, mode, transactionId, note,
///   date (Timestamp), paidAt (server), receivedAt (set by the student)
/// }
class SponsorPaymentCard extends StatelessWidget {
  final String applicationId;
  final String? defaultAmount;

  const SponsorPaymentCard({
    super.key,
    required this.applicationId,
    this.defaultAmount,
  });

  static const _modes = ['Bank Transfer', 'UPI', 'Cheque', 'Cash'];

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('applications').doc(applicationId);

  String _date(dynamic t) =>
      t is Timestamp ? DateFormat('d MMM yyyy').format(t.toDate()) : '-';

  Future<void> _openDialog(BuildContext context) async {
    final amountCtrl = TextEditingController(
        text: (defaultAmount ?? '').replaceAll(RegExp(r'[^0-9.]'), ''));
    final txnCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String mode = _modes.first;
    DateTime date = DateTime.now();
    String? error;
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Record scholarship payment"),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Amount paid (\u20B9)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: mode,
                    decoration: const InputDecoration(
                      labelText: "Payment mode",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final m in _modes)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => setS(() => mode = v ?? mode),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txnCtrl,
                    decoration: InputDecoration(
                      labelText: mode == 'Cash'
                          ? "Receipt / reference no. (optional)"
                          : "Transaction / cheque ID",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setS(() => date = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Payment date",
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                      child: Text(DateFormat('d MMM yyyy').format(date)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Note (optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!,
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogCtx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                final amt = double.tryParse(amountCtrl.text.trim());
                if (amt == null || amt <= 0) {
                  setS(() => error = "Enter a valid amount.");
                  return;
                }
                if (mode != 'Cash' && txnCtrl.text.trim().isEmpty) {
                  setS(() => error = "Enter the transaction / cheque ID.");
                  return;
                }
                setS(() {
                  saving = true;
                  error = null;
                });
                try {
                  await _ref.update({
                    'payment': {
                      'status': 'Paid',
                      'amount': amt == amt.roundToDouble() ? amt.toInt() : amt,
                      'mode': mode,
                      'transactionId': txnCtrl.text.trim(),
                      'note': noteCtrl.text.trim(),
                      'date': Timestamp.fromDate(date),
                      'paidAt': FieldValue.serverTimestamp(),
                    },
                  });
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                } catch (e) {
                  setS(() {
                    saving = false;
                    error = "Could not save: $e";
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(saving ? "Saving..." : "Mark as Paid"),
            ),
          ],
        ),
      ),
    );

    amountCtrl.dispose();
    txnCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) return const SizedBox.shrink();

        final status = (data['status'] ?? '').toString();
        if (status != 'Approved') return const SizedBox.shrink();

        final Map<String, dynamic>? p = data['payment'] as Map<String, dynamic>?;
        final String st = p?['status']?.toString() ?? '';
        final bool paid = st == 'Paid';
        final bool received = st == 'Received';

        final Color color = received
            ? AppColors.success
            : paid
            ? AppColors.primary
            : AppColors.warning;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      received
                          ? Icons.verified_rounded
                          : Icons.account_balance_wallet_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Scholarship Payment",
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          received
                              ? "Student confirmed on ${_date(p?['receivedAt'])}."
                              : paid
                              ? "Paid. Waiting for the student to confirm."
                              : "Approved. Record the payment once you send it.",
                          style: AppTextStyles.subtitle.copyWith(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      received
                          ? "RECEIVED"
                          : paid
                          ? "PAID"
                          : "PENDING",
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                  ),
                ],
              ),
              if (paid || received) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _row("Amount", "\u20B9${p?['amount'] ?? '-'}"),
                _row("Mode", p?['mode']?.toString() ?? '-'),
                if ((p?['transactionId'] ?? '').toString().isNotEmpty)
                  _row("Transaction ID", p!['transactionId'].toString()),
                _row("Paid on", _date(p?['date'])),
                if ((p?['note'] ?? '').toString().isNotEmpty)
                  _row("Note", p!['note'].toString()),
              ] else ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDialog(context),
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text("Record Payment"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: AppTextStyles.subtitle.copyWith(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: AppTextStyles.subtitle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
      ],
    ),
  );
}