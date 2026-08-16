import 'package:flutter/material.dart';

import '../services/app_theme.dart';

class JotCueMark extends StatelessWidget {
  const JotCueMark({super.key, this.size = 44, this.showTile = true});

  final double size;
  final bool showTile;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/branding/jotcue_foreground.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'JotCue',
    );

    if (!showTile) {
      return mark;
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: AppColors.brandInk,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: mark,
    );
  }
}

class JotCueLockup extends StatelessWidget {
  const JotCueLockup({super.key, this.markSize = 44, this.foregroundColor});

  final double markSize;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        JotCueMark(size: markSize),
        SizedBox(width: markSize * 0.25),
        Text(
          'JotCue',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.45,
          ),
        ),
      ],
    );
  }
}
