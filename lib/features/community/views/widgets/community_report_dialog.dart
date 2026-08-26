import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/community_models.dart';

Future<CommunityReportSubmission?> showCommunityReportDialog(
  BuildContext context, {
  required String contentLabel,
}) {
  return showModalBottomSheet<CommunityReportSubmission>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => _CommunityReportSheet(contentLabel: contentLabel),
  );
}

class CommunityReportSubmission {
  const CommunityReportSubmission({required this.reason, this.details});

  final CommunityReportReason reason;
  final String? details;
}

class _CommunityReportSheet extends StatefulWidget {
  const _CommunityReportSheet({required this.contentLabel});

  final String contentLabel;

  @override
  State<_CommunityReportSheet> createState() => _CommunityReportSheetState();
}

class _CommunityReportSheetState extends State<_CommunityReportSheet> {
  final _detailsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  CommunityReportReason _reason = CommunityReportReason.spam;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _reason == CommunityReportReason.other;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report ${widget.contentLabel}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Tell the moderation team what needs attention.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<CommunityReportReason>(
                initialValue: _reason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: CommunityReportReason.values
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _reason = value);
                },
              ),
              if (isOther) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _detailsController,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Report reason',
                    hintText: 'Describe what should be reviewed',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (isOther && (value == null || value.trim().isEmpty)) {
                      return 'Add a reason for selecting Other';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        context.pop(
                          CommunityReportSubmission(
                            reason: _reason,
                            details: _detailsController.text.trim(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
