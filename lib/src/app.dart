import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

class RunProgramApp extends StatelessWidget {
  const RunProgramApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RUN//PROGRAM',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: const WelcomeScreen(),
  );
}
