import 'package:flutter/material.dart';

class PonderaHeader extends StatelessWidget {
  const PonderaHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 48,
              child: Image.asset(
                'assets/branding/pondera_logo.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Pondera',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
      ],
    );
  }
}

class PonderaThemeSelector extends StatelessWidget {
  const PonderaThemeSelector({
    required this.themeMode,
    required this.onChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ThemeMode>(
      initialValue: themeMode,
      tooltip: 'Tema visual',
      icon: Icon(_iconFor(themeMode)),
      onSelected: onChanged,
      itemBuilder: (context) => ThemeMode.values.map((mode) {
        return PopupMenuItem(
          value: mode,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: mode == themeMode
                    ? const Icon(Icons.check, size: 18)
                    : null,
              ),
              Icon(_iconFor(mode), size: 18),
              const SizedBox(width: 10),
              Text(_labelFor(mode)),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _iconFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };
  }

  String _labelFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Seguir al sistema',
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Oscuro',
    };
  }
}
