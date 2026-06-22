import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';

class RecipeActionsPanel extends StatelessWidget {
  const RecipeActionsPanel({
    required this.savedRegex,
    required this.isEnabled,
    required this.isProcessing,
    required this.onSendToN8n,
    required this.onClearRecipe,
    super.key,
  });

  final String savedRegex;
  final bool isEnabled;
  final bool isProcessing;
  final VoidCallback onSendToN8n;
  final VoidCallback onClearRecipe;

  bool get hasActiveRecipe => savedRegex.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SettingsExpansionCard(
      title: 'Receta de lectura',
      summary: isProcessing
          ? 'Procesando con n8n…'
          : (hasActiveRecipe ? 'Receta activa' : 'Sin receta configurada'),
      icon: Icons.data_object,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isProcessing
                ? 'n8n está analizando la trama. La aplicación puede seguir utilizándose.'
                : 'Envía la última trama a n8n para crear o actualizar la regla de lectura.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (isProcessing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (hasActiveRecipe) ...[
            const SizedBox(height: 12),
            Text(
              'Expresión activa',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            SelectableText(
              savedRegex,
              style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: isEnabled && !isProcessing ? onSendToN8n : null,
                icon: isProcessing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_outlined),
                label: Text(
                  isProcessing
                      ? 'Procesando…'
                      : (hasActiveRecipe
                            ? 'Actualizar receta'
                            : 'Crear receta'),
                ),
              ),
              if (hasActiveRecipe)
                TextButton.icon(
                  onPressed: isEnabled && !isProcessing
                      ? () => _confirmClearRecipe(context)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar receta'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearRecipe(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar receta'),
          content: const Text(
            'Pondera dejará de interpretar las tramas hasta crear una receta nueva.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      onClearRecipe();
    }
  }
}
