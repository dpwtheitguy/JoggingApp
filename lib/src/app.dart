import 'package:flutter/material.dart';

import 'screens/coach_screen.dart';
import 'data/coach_store.dart';
import 'theme/app_theme.dart';

class RunProgramApp extends StatelessWidget {
  const RunProgramApp({super.key, this.store});
  final CoachStore? store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RUN//PROGRAM',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: CoachScreen(store: store),
  );
}
