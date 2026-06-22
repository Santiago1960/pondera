import 'package:flutter/material.dart';

import '../features/scale_reading/presentation/main_screen.dart';
import '../features/settings/data/settings_repository.dart';
import 'app_theme.dart';

class PonderaApp extends StatefulWidget {
  const PonderaApp({super.key});

  @override
  State<PonderaApp> createState() => _PonderaAppState();
}

class _PonderaAppState extends State<PonderaApp> {
  ThemeMode _themeMode = ThemeMode.system;
  SettingsRepository? _settingsRepository;
  bool _themeChangedByUser = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final repository = await SettingsRepository.create();
    final themeMode = themeModeFromPreference(repository.loadThemeMode());
    if (!mounted) {
      return;
    }
    setState(() {
      _settingsRepository = repository;
      if (!_themeChangedByUser) {
        _themeMode = themeMode;
      }
    });
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    setState(() {
      _themeChangedByUser = true;
      _themeMode = themeMode;
    });
    final repository = _settingsRepository ?? await SettingsRepository.create();
    _settingsRepository = repository;
    await repository.saveThemeMode(themeMode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pondera',
      theme: buildPonderaTheme(Brightness.light),
      darkTheme: buildPonderaTheme(Brightness.dark),
      themeMode: _themeMode,
      home: MainScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _changeThemeMode,
      ),
    );
  }
}
