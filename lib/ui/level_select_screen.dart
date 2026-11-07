import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../logic/progress.dart';
import '../model/board.dart';
import '../model/levels.dart';
import '../painting/watercolor.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'game_screen.dart';
import 'widgets.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int _unlocked = 1;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final u = await Progress.unlocked();
    if (mounted) setState(() => _unlocked = u);
  }

  bool _isOpen(Level l) =>
      widget.mode == GameMode.twoPlayers || l.number <= _unlocked;

  Future<void> _start(Level level) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(level: level, mode: widget.mode),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Zurück',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.mode == GameMode.vsComputer
                        ? 'Gegen den Computer'
                        : 'Zwei Spieler',
                    style: AppText.title(30),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: levels.length,
              itemBuilder: (context, i) {
                final l = levels[i];
                return _LevelCard(
                  level: l,
                  open: _isOpen(l),
                  won:
                      widget.mode == GameMode.vsComputer &&
                      l.number < _unlocked,
                  onTap: () => _start(l),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.open,
    required this.won,
    required this.onTap,
  });

  final Level level;
  final bool open;
  final bool won;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = WheelColor.values[(level.number - 1) % 6];
    return Semantics(
      button: open,
      label: 'Level ${level.number}: ${level.name}${open ? '' : ', gesperrt'}',
      child: GestureDetector(
        onTap: open ? onTap : null,
        child: MouseRegion(
          cursor: open ? SystemMouseCursors.click : MouseCursor.defer,
          child: Opacity(
            opacity: open ? 1 : 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Inks.paper.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Inks.paperDeep, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Inks.paperDeep.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 34,
                          height: 30,
                          child: CustomPaint(
                            painter: BrushStrokePainter(
                              tint.pigment,
                              level.number,
                            ),
                            child: Center(
                              child: Text(
                                '${level.number}',
                                style: AppText.hand(24),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!open)
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Inks.graphite,
                          ),
                        if (won)
                          Icon(
                            Icons.check_rounded,
                            size: 22,
                            color: WheelColor.green.deep,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: CustomPaint(
                        painter: _BoardPreviewPainter(level),
                        size: Size.infinite,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(level.name, style: AppText.title(21)),
                    Text(
                      level.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(12, color: Inks.graphite),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardPreviewPainter extends CustomPainter {
  _BoardPreviewPainter(this.level) : spec = level.build();

  final Level level;
  final BoardSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = spec.positions;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final pad = 8.0;
    final scale = math.min(
      (size.width - 2 * pad) / math.max(maxX - minX, 0.001),
      (size.height - 2 * pad) / math.max(maxY - minY, 0.001),
    );
    final centre = size.center(Offset.zero);
    final mid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    Offset at(int i) => centre + (pts[i] - mid) * scale;

    final rng = math.Random(level.number);
    for (final (a, b) in spec.edges) {
      Watercolor.pencilLine(canvas, at(a), at(b), rng, width: 0.9);
    }
    final r = math.max(3.0, scale * 0.22);
    for (var i = 0; i < pts.length; i++) {
      final preset = spec.preset[i];
      if (preset != null) {
        Watercolor.drawDisc(canvas, at(i), r, preset.pigment, i + 3);
      } else {
        canvas.drawCircle(at(i), r, Paint()..color = Inks.paperShade);
        canvas.drawCircle(
          at(i),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = Inks.graphite.withValues(alpha: 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPreviewPainter old) => old.level != level;
}
