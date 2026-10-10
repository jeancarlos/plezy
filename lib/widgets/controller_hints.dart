import 'package:flutter/material.dart';

import '../i18n/strings.g.dart';

enum ControllerButtonType { a, b, x, y, lb, rb, lt, rt, start, view }

class ControllerGlyph extends StatelessWidget {
  final ControllerButtonType type;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ControllerGlyph({super.key, required this.type, this.size = 24, this.backgroundColor, this.foregroundColor});

  String _getLabel() {
    return switch (type) {
      ControllerButtonType.a => 'A',
      ControllerButtonType.b => 'B',
      ControllerButtonType.x => 'X',
      ControllerButtonType.y => 'Y',
      ControllerButtonType.lb => 'LB',
      ControllerButtonType.rb => 'RB',
      ControllerButtonType.lt => 'LT',
      ControllerButtonType.rt => 'RT',
      ControllerButtonType.start => '≡',
      ControllerButtonType.view => '⊞',
    };
  }

  bool _isPill() {
    return switch (type) {
      ControllerButtonType.a || ControllerButtonType.b || ControllerButtonType.x || ControllerButtonType.y => false,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Theme.of(context).colorScheme.primary;
    final fgColor = foregroundColor ?? Theme.of(context).colorScheme.onPrimary;

    if (_isPill()) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.4, vertical: size * 0.2),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Text(
          _getLabel(),
          style: TextStyle(color: fgColor, fontSize: size * 0.8, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _getLabel(),
        style: TextStyle(color: fgColor, fontSize: size * 0.6, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ControllerHintsRow extends StatelessWidget {
  final List<(ControllerButtonType, String)> hints;
  final double glyphSize;
  final double spacing;

  const ControllerHintsRow({super.key, required this.hints, this.glyphSize = 20, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    if (hints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < hints.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ControllerGlyph(type: hints[i].$1, size: glyphSize),
                SizedBox(width: spacing * 0.5),
                Flexible(
                  child: Text(
                    hints[i].$2,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class BrowseControllerHints extends StatelessWidget {
  final bool showTabs;

  const BrowseControllerHints({super.key, this.showTabs = false});

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);

    final hints = [
      (ControllerButtonType.a, t.controllerHints.select),
      (ControllerButtonType.b, t.controllerHints.back),
      (ControllerButtonType.y, t.controllerHints.options),
      if (showTabs) ...[
        (ControllerButtonType.lb, t.controllerHints.previousTab),
        (ControllerButtonType.rb, t.controllerHints.nextTab),
      ],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ControllerHintsRow(hints: hints),
    );
  }
}

class PlayerControllerHints extends StatelessWidget {
  const PlayerControllerHints({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);

    final hints = [
      (ControllerButtonType.a, t.controllerHints.select),
      (ControllerButtonType.b, t.controllerHints.back),
      (ControllerButtonType.x, t.controllerHints.playPause),
      (ControllerButtonType.y, t.controllerHints.audioSubs),
      (ControllerButtonType.lt, t.controllerHints.rewindSeek),
      (ControllerButtonType.rt, t.controllerHints.forwardSeek),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ControllerHintsRow(hints: hints, glyphSize: 16, spacing: 8),
    );
  }
}
