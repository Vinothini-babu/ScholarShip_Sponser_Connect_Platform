import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// One stage in an application's journey, optionally read from Firestore's
/// `statusHistory` array (added when an admin acts on the application):
///
/// applications/{applicationId} {
///   status: "Approved",
///   appliedAt: Timestamp,
///   statusHistory: [
///     { status: "Under Review", timestamp: Timestamp, note: "" },
///     { status: "Approved", timestamp: Timestamp, note: "Docs verified" },
///   ]
/// }
///
/// NOTE: "Submitted" does NOT need an entry here — it's derived from
/// `appliedAt`, since the application existing at all means it was
/// submitted. Only write history entries for "Under Review" / "Approved" /
/// "Rejected" transitions.
class StatusHistoryEntry {
  final String status;
  final DateTime timestamp;
  final String? note;

  StatusHistoryEntry({
    required this.status,
    required this.timestamp,
    this.note,
  });

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    final ts = map['timestamp'];
    return StatusHistoryEntry(
      status: map['status']?.toString() ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
      note: map['note']?.toString(),
    );
  }

  static List<StatusHistoryEntry> listFromData(Map<String, dynamic> data) {
    final List<dynamic> raw = data['statusHistory'] ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(StatusHistoryEntry.fromMap)
        .toList();
  }
}

enum _StageState { completed, active, notStarted, rejected }

class _Stage {
  final String label;
  final _StageState state;
  final DateTime? timestamp;
  final String? note;
  const _Stage(this.label, this.state, {this.timestamp, this.note});
}

/// Flipkart/e-commerce-style order-tracking card: collapsible header with
/// the current status as the headline, a horizontal progress tracker, a
/// contextual info note, and a low-emphasis "See all updates" toggle.
class StatusTimeline extends StatefulWidget {
  final List<StatusHistoryEntry> history;
  final String currentStatus; // "Pending" | "Approved" | "Rejected"
  final DateTime? appliedAt;

  const StatusTimeline({
    super.key,
    required this.history,
    required this.currentStatus,
    this.appliedAt,
  });

  @override
  State<StatusTimeline> createState() => _StatusTimelineState();
}

class _StatusTimelineState extends State<StatusTimeline> {
  bool _expanded = true; // matches the reference design's default-open card

  StatusHistoryEntry? _entryFor(String stage) {
    for (final e in widget.history) {
      if (e.status.toLowerCase() == stage.toLowerCase()) return e;
    }
    return null;
  }

  List<_Stage> get _stages {
    final reviewEntry = _entryFor('Under Review');
    final decisionEntry = _entryFor(widget.currentStatus);

    final submitted = _Stage('Submitted', _StageState.completed, timestamp: widget.appliedAt);

    switch (widget.currentStatus.toLowerCase()) {
      case 'approved':
        return [
          submitted,
          _Stage('Under Review', _StageState.completed, timestamp: reviewEntry?.timestamp),
          _Stage('Approved', _StageState.completed,
              timestamp: decisionEntry?.timestamp, note: decisionEntry?.note),
        ];
      case 'rejected':
        return [
          submitted,
          _Stage('Under Review', _StageState.completed, timestamp: reviewEntry?.timestamp),
          _Stage('Rejected', _StageState.rejected,
              timestamp: decisionEntry?.timestamp, note: decisionEntry?.note),
        ];
      default: // Pending
        return [
          submitted,
          _Stage('Under Review', _StageState.active, timestamp: reviewEntry?.timestamp),
          const _Stage('Approved', _StageState.notStarted),
        ];
    }
  }

  Color _colorFor(_StageState state) {
    switch (state) {
      case _StageState.completed:
        return AppColors.success;
      case _StageState.active:
        return AppColors.primary;
      case _StageState.rejected:
        return AppColors.error;
      case _StageState.notStarted:
        return Colors.grey.shade400;
    }
  }

  /// Headline + one-line subtitle, mirroring how a courier app names the
  /// card after whatever milestone is currently in focus.
  (String, String) get _headline {
    switch (widget.currentStatus.toLowerCase()) {
      case 'approved':
        return ("Application Approved", "Congratulations! Your application has been approved.");
      case 'rejected':
        return ("Application Not Approved", "Your application was not approved this time.");
      default:
        return ("Application Submitted", "Your application has been submitted and is under review.");
    }
  }

  String? get _infoNote {
    final stages = _stages;
    final noted = stages.lastWhere(
          (s) => s.note != null && s.note!.trim().isNotEmpty,
      orElse: () => const _Stage('', _StageState.notStarted),
    );
    if (noted.note != null && noted.note!.trim().isNotEmpty) {
      return noted.note;
    }

    switch (widget.currentStatus.toLowerCase()) {
      case 'approved':
        return "You'll be notified with next steps for receiving your scholarship benefits.";
      case 'rejected':
        return "You can reach out to the sponsor for more details on this decision.";
      default:
        return "You'll be notified as soon as the sponsor reviews your application.";
    }
  }

  String _dateShort(DateTime d) => DateFormat('MMM d').format(d);
  String _timeShort(DateTime d) => DateFormat('h:mm a').format(d);

  static const double _nodeSize = 26;

  @override
  Widget build(BuildContext context) {
    final stages = _stages;
    final (title, subtitle) = _headline;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
          // ---- Header (always visible, tap to collapse/expand) ----
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Horizontal tracker ----
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < stages.length; i++) ...[
                        _buildNode(stages[i]),
                        if (i != stages.length - 1)
                          Expanded(
                            child: SizedBox(
                              height: _nodeSize,
                              child: Center(
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: (stages[i].state == _StageState.completed ||
                                        stages[i].state == _StageState.rejected)
                                        ? _colorFor(stages[i].state)
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),

                  if (_infoNote != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _infoNote!,
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // ---- Low-emphasis "See all updates" ----
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    _expanded ? "Hide updates" : "See all updates",
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNode(_Stage stage) {
    final color = _colorFor(stage.state);
    final bool isFilled = stage.state != _StageState.notStarted;

    Widget icon;
    switch (stage.state) {
      case _StageState.completed:
        icon = const Icon(Icons.check, size: 14, color: Colors.white);
        break;
      case _StageState.rejected:
        icon = const Icon(Icons.close, size: 14, color: Colors.white);
        break;
      case _StageState.active:
        icon = Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        );
        break;
      case _StageState.notStarted:
        icon = const SizedBox.shrink();
        break;
    }

    final String subtitle = stage.timestamp != null
        ? "${_dateShort(stage.timestamp!)}\n${_timeShort(stage.timestamp!)}"
        : stage.state == _StageState.active
        ? "In progress"
        : stage.state == _StageState.rejected
        ? "Not approved"
        : "Pending";

    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Container(
            width: _nodeSize,
            height: _nodeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isFilled ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: stage.state == _StageState.active
                  ? [BoxShadow(color: color.withOpacity(0.28), blurRadius: 8, spreadRadius: 2)]
                  : null,
            ),
            child: icon,
          ),
          const SizedBox(height: 7),
          Text(
            stage.label,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: stage.state == _StageState.notStarted
                  ? Colors.grey.shade400
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 10,
              height: 1.2,
              fontWeight: stage.state == _StageState.active ? FontWeight.w600 : FontWeight.normal,
              color: stage.state == _StageState.active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}