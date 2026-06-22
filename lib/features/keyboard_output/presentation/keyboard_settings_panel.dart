import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';

class KeyboardSettingsPanel extends StatelessWidget {
  const KeyboardSettingsPanel({
    required this.prefixController,
    required this.suffixController,
    required this.onSave,
    super.key,
  });

  final TextEditingController prefixController;
  final TextEditingController suffixController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SettingsExpansionCard(
      title: 'Comandos de teclado',
      summary: 'Prefijo y sufijo para escritura automática',
      icon: Icons.keyboard_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comandos disponibles: {TAB}, {ENTER}, {SPACE}, {AHORA}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: prefixController,
                  decoration: const InputDecoration(
                    labelText: 'Prefijo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'IBMPlexMono',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: suffixController,
                  decoration: const InputDecoration(
                    labelText: 'Sufijo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'IBMPlexMono',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                ),
                child: const Icon(Icons.save, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
