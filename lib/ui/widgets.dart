import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../painting/watercolor.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';

/// Full-screen paper with the content held in a phone-width column.
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({super.key, required this.child});

  final Widget child;

  /// From this width on, the game sits as a sheet on a desk background.
  static const desktopBreakpoint = 640.0;

  @override
  Widget build(BuildContext context) {
    final paper = Stack(
      children: [
        const Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: PaperPainter())),
        ),
        Positioned.fill(child: child),
      ],
    );
    return Scaffold(
      backgroundColor: Inks.paper,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < desktopBreakpoint) {
            return SafeArea(child: paper);
          }
          // Phone-like proportions, as tall as the window allows.
          final height = (constraints.maxHeight - 48).clamp(560.0, 920.0);
          final width = (height * 0.5).clamp(400.0, 460.0);
          return Stack(
            children: [
              const Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: DeskPainter()),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Inks.ink.withValues(alpha: 0.10),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                        BoxShadow(
                          color: Inks.ink.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: paper,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The colour wheel as a horizontal watercolour gradient with labels.
/// Marks [selected] and its complement when a card is picked.
/// On the twelve-colour wheel only the main colours are labelled, or, with a
/// card picked, the picked colour and its complement.
class WheelStrip extends StatelessWidget {
  const WheelStrip({super.key, this.selected, this.wheel = ColorWheel.classic});

  final WheelColor? selected;
  final ColorWheel wheel;

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    return Semantics(
      label:
          'Farbkreis: ${wheel.colors.map((c) => c.label).join(', ')}, '
          'dann wieder Gelb',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          double centreOf(WheelColor c) =>
              w * (wheel.indexOf(c) + 0.5) / wheel.length;
          final crowded = wheel.length > ColorWheel.classic.length;
          final labelled = [
            for (final c in wheel.colors)
              if (!crowded
                  ? true
                  : sel == null
                  ? ColorWheel.classic.colors.contains(c)
                  : c == sel || c == sel.complement)
                c,
          ];
          return SizedBox(
            height: 46,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 10,
                  height: 16,
                  child: CustomPaint(painter: _WheelStripPainter(wheel)),
                ),
                if (crowded)
                  for (final c in wheel.colors)
                    Positioned(
                      left: centreOf(c) - 0.5,
                      width: 1,
                      top: 6,
                      height: 4,
                      child: ColoredBox(
                        color: Inks.graphite.withValues(alpha: 0.5),
                      ),
                    ),
                for (final c in labelled)
                  Positioned(
                    left: centreOf(c) - 40,
                    width: 80,
                    top: 27,
                    child: Text(
                      c.label,
                      textAlign: TextAlign.center,
                      style: AppText.hand(
                        14,
                        color: sel == null || c == sel || c == sel.complement
                            ? Inks.ink.withValues(alpha: 0.7)
                            : Inks.graphite.withValues(alpha: 0.6),
                        weight: c == sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                if (sel != null) ...[
                  _StripMarker(x: centreOf(sel), filled: true),
                  _StripMarker(x: centreOf(sel.complement), filled: false),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StripMarker extends StatelessWidget {
  const _StripMarker({required this.x, required this.filled});

  final double x;
  final bool filled;

  @override
  Widget build(BuildContext context) => AnimatedPositioned(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
    left: x - 5,
    top: 0,
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Inks.ink.withValues(alpha: 0.7) : null,
        border: Border.all(color: Inks.ink.withValues(alpha: 0.7), width: 1.5),
      ),
    ),
  );
}

class _WheelStripPainter extends CustomPainter {
  const _WheelStripPainter(this.wheel);

  final ColorWheel wheel;

  @override
  void paint(Canvas canvas, Size size) =>
      Watercolor.wheelStrip(canvas, Offset.zero & size, 23, wheel: wheel);

  @override
  bool shouldRepaint(_WheelStripPainter oldDelegate) =>
      oldDelegate.wheel != wheel;
}

class PaintedDisc extends StatelessWidget {
  const PaintedDisc({
    super.key,
    required this.color,
    required this.size,
    this.seed = 1,
    this.opacity = 1,
  });

  final WheelColor color;
  final double size;
  final int seed;
  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: DiscPainter(color, seed, opacity: opacity)),
  );
}

/// Text button with a watercolour brush stroke behind its label.
class BrushButton extends StatefulWidget {
  const BrushButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = WheelColor.blue,
    this.seed = 3,
    this.fontSize = 30,
  });

  final String label;
  final VoidCallback? onPressed;
  final WheelColor color;
  final int seed;
  final double fontSize;

  @override
  State<BrushButton> createState() => _BrushButtonState();
}

class _BrushButtonState extends State<BrushButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final strength = !enabled
        ? 0.25
        : _down
        ? 1.0
        : _hover
        ? 0.85
        : 0.6;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled
            ? () {
                Sound.click();
                widget.onPressed!();
              }
            : null,
        child: Semantics(
          button: true,
          label: widget.label,
          child: CustomPaint(
            painter: BrushStrokePainter(
              widget.color.pigment,
              widget.seed,
              opacity: strength,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.fontSize * 1.1,
                vertical: widget.fontSize * 0.32,
              ),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: AppText.hand(
                  widget.fontSize,
                  color: enabled ? Inks.ink : Inks.graphite,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: () {
      Sound.click();
      onPressed();
    },
    tooltip: tooltip,
    icon: Icon(icon, color: Inks.ink.withValues(alpha: 0.75)),
    style: IconButton.styleFrom(
      backgroundColor: Inks.paperShade.withValues(alpha: 0.5),
    ),
  );
}

/// Switches music and sound effects on or off.
class SoundButton extends StatelessWidget {
  const SoundButton({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: Sound.muted,
    builder: (context, muted, _) => IconButton(
      onPressed: Sound.toggleMuted,
      tooltip: muted ? 'Ton an' : 'Ton aus',
      icon: Icon(
        muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: Inks.ink.withValues(alpha: 0.75),
      ),
      style: IconButton.styleFrom(
        backgroundColor: Inks.paperShade.withValues(alpha: 0.5),
      ),
    ),
  );
}

/// The six colours arranged as a wheel, slowly breathing.
class ColorWheelEmblem extends StatefulWidget {
  const ColorWheelEmblem({super.key, required this.size});

  final double size;

  @override
  State<ColorWheelEmblem> createState() => _ColorWheelEmblemState();
}

class _ColorWheelEmblemState extends State<ColorWheelEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final disc = s * 0.34;
    return SizedBox.square(
      dimension: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final turn = _c.value * 2 * math.pi;
          return Stack(
            children: [
              for (final color in ColorWheel.classic.colors)
                Positioned(
                  left:
                      s / 2 +
                      math.cos(
                            turn -
                                math.pi / 2 +
                                ColorWheel.classic.indexOf(color) * math.pi / 3,
                          ) *
                          (s / 2 - disc / 2) -
                      disc / 2,
                  top:
                      s / 2 +
                      math.sin(
                            turn -
                                math.pi / 2 +
                                ColorWheel.classic.indexOf(color) * math.pi / 3,
                          ) *
                          (s / 2 - disc / 2) -
                      disc / 2,
                  child: PaintedDisc(
                    color: color,
                    size: disc,
                    seed: 40 + color.index,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
