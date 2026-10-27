import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

enum LabelAction { print, edit, duplicate, preview, delete }

/// One label in the series list.
class LabelCard extends StatelessWidget {
  const LabelCard({
    super.key,
    required this.index,
    required this.label,
    required this.onAction,
    this.busy = false,
    this.enabled = true,
  });

  final int index;
  final CargoLabel label;
  final bool busy;
  final bool enabled;
  final void Function(LabelAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final receiver = label.receiver.isNotEmpty ? label.receiver.first : '';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? () => onAction(LabelAction.edit) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${label.bookingReference}  ·  ${label.item}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (label.cargoName.trim().isNotEmpty) label.cargoName,
                            receiver.isEmpty ? '${label.source} → ${label.destination}' : '$receiver → ${label.destination}',
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<LabelAction>(
                    enabled: enabled,
                    onSelected: onAction,
                    icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: LabelAction.print, child: _MenuRow(Icons.print_rounded, 'Print this label')),
                      PopupMenuItem(value: LabelAction.edit, child: _MenuRow(Icons.edit_rounded, 'Edit')),
                      PopupMenuItem(value: LabelAction.duplicate, child: _MenuRow(Icons.copy_rounded, 'Duplicate')),
                      PopupMenuItem(value: LabelAction.preview, child: _MenuRow(Icons.code_rounded, 'View TSPL')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: LabelAction.delete, child: _MenuRow(Icons.delete_outline_rounded, 'Delete', danger: true)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(Icons.place_outlined, label.source),
                    _Chip(Icons.scale_rounded, label.weight),
                    _Chip(Icons.inventory_2_outlined, label.package),
                    _Chip(Icons.event_rounded, label.date),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.text, {this.danger = false});
  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}
