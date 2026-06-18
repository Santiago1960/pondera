import 'package:flutter/material.dart';

import '../features/scale_reading/presentation/main_screen.dart';
import 'app_theme.dart';

class PonderaApp extends StatelessWidget {
  const PonderaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pondera',
      theme: buildPonderaTheme(),
      home: const MainScreen(),
    );
  }
}
