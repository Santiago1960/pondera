import 'package:flutter/material.dart';

class SettingsExpansionCard extends StatelessWidget {
  const SettingsExpansionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.summary,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String? summary;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: summary == null || summary!.isEmpty
            ? null
            : Text(
                summary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}
