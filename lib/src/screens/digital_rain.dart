import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DigitalRain extends StatefulWidget {
  const DigitalRain({super.key});
  @override
  State<DigitalRain> createState() => _DigitalRainState();
}

class _DigitalRainState extends State<DigitalRain> with WidgetsBindingObserver {
  Timer? timer;
  int frame = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  void start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(milliseconds: 125), (_) {
      if (mounted) setState(() => frame++);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      start();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(child: CustomPaint(painter: _RainPainter(frame))),
  );
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.frame);
  final int frame;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 12; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: '${(frame ~/ 8 + i) % 2}\n${i % 2}\n1',
          style: TextStyle(
            fontSize: 14,
            height: 1.8,
            color: AppTheme.primary.withValues(alpha: .06),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          size.width * i / 12,
          ((frame * 3 + i * 97) % (size.height + 100)) - 100,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => frame != old.frame;
}
