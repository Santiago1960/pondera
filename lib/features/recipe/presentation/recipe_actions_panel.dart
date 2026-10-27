import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';

class RecipeActionsPanel extends StatelessWidget {
  const RecipeActionsPanel({
    required this.savedRegex,
    required this.isEnabled,
    required this.isProcessing,
    required this.onSendToN8n,
    required this.onExportOfflineRequest,
    required this.onImportAuthorizedRecipe,
    this.canUseOffline = false,
    required this.onClearRecipe,
    super.key,
  });

  final String savedRegex;
  final bool isEnabled;
  final bool isProcessing;
  final VoidCallback onSendToN8n;
  final VoidCallback onExportOfflineRequest;
  final VoidCallback onImportAuthorizedRecipe;
  final bool canUseOffline;
  final VoidCallback onClearRecipe;

  bool get hasActiveRecipe => savedRegex.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SettingsExpansionCard(
      title: 'Receta de lectura',
      summary: isProcessing
          ? 'Analizando la muestra…'
          : (hasActiveRecipe ? 'Receta activa' : 'Sin receta configurada'),
      icon: Icons.data_object,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isProcessing
                ? 'Analizando la muestra y creando la receta… La aplicación puede seguir utilizándose.'
                : 'Crea la receta por internet o solicita a Bitgenial un archivo autorizado para este equipo.',
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
              'Receta protegida activa',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pondera conserva la receta protegida y comprueba su autorización al abrir la aplicación.',
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
              OutlinedButton.icon(
                onPressed: isEnabled && !isProcessing && canUseOffline
                    ? onExportOfflineRequest
                    : null,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Solicitar receta sin internet'),
              ),
              OutlinedButton.icon(
                onPressed: isEnabled && !isProcessing && canUseOffline
                    ? onImportAuthorizedRecipe
                    : null,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Cargar receta autorizada'),
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
          const SizedBox(height: 10),
          const Text(
            'Sin internet: guarda la solicitud y envíala a Bitgenial por otro dispositivo. Luego carga el archivo de respuesta. Requiere una licencia importada vigente.',
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
