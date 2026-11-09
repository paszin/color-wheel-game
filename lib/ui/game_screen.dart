import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/color_wheel_game.dart';
import '../logic/ai.dart';
import '../logic/difficulty.dart';
import '../logic/game_state.dart';
import '../logic/progress.dart';
import '../model/board.dart';
import '../model/levels.dart';
import '../painting/watercolor.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'rules_sheet.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.level,
    required this.mode,
    this.difficulty = Difficulty.medium,
  });

  final Level level;
  final GameMode mode;
  final Difficulty difficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _state;
  late ColorWheelGame _game;
  final _rng = math.Random();
  int? _selected;
  bool _showResult = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _timer?.cancel();
    _state = GameState(widget.level, widget.mode);
    _game = ColorWheelGame(state: _state, onNodeTap: _onNodeTap);
    _selected = null;
    _showResult = false;
    _syncGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _humanTurn => !_state.isOver && !_state.currentPlayer.isComputer;

  /// Player whose hand is shown large at the bottom.
  int get _handOwner => widget.mode == GameMode.vsComputer ? 0 : _state.current;

  void _syncGame() {
    _game.interactive = _humanTurn;
    _game.selectedColor = _selected == null || !_humanTurn
        ? null
        : _state.currentPlayer.hand[_selected!];
  }

  void _select(int i) {
    if (!_humanTurn) return;
    setState(() {
      _selected = _selected == i ? null : i;
      _syncGame();
    });
  }

  void _onNodeTap(ColorNode node) {
    final i = _selected;
    if (!_humanTurn || i == null || !node.isEmpty) return;
    _play(i, node);
  }

  void _play(int handIndex, ColorNode node) {
    final player = _state.current;
    final result = _state.play(handIndex, node);
    _game.showMove(result, player);
    setState(() {
      _selected = null;
      _syncGame();
    });

    if (_state.isOver) {
      _timer = Timer(const Duration(milliseconds: 1800), _finish);
    } else if (_state.currentPlayer.isComputer) {
      final wait = 900 + result.events.length * 400;
      _timer = Timer(Duration(milliseconds: wait), _computerTurn);
    }
  }

  /// Shown before the first move against the computer.
  bool get _canLetComputerStart =>
      widget.mode == GameMode.vsComputer && _state.notStarted && _humanTurn;

  void _letComputerStart() {
    if (!_canLetComputerStart) return;
    _state.secondPlayerStarts();
    setState(() {
      _selected = null;
      _syncGame();
    });
    _timer = Timer(const Duration(milliseconds: 600), _computerTurn);
  }

  void _computerTurn() {
    if (!mounted || _state.isOver) return;
    final move = chooseAiMove(
      _state,
      widget.difficulty.skillFor(widget.level),
      _rng,
    );
    _play(move.handIndex, move.node);
  }

  void _finish() {
    if (!mounted) return;
    if (widget.mode == GameMode.vsComputer && _state.winner == 0) {
      Progress.unlock(widget.level.number + 1);
    }
    setState(() => _showResult = true);
  }

  void _restart() => setState(_newGame);

  void _nextLevel() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          level: levels[widget.level.number],
          mode: widget.mode,
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  String get _status {
    if (_state.isOver) return 'Alle Felder sind bemalt';
    final p = _state.currentPlayer;
    if (p.isComputer) return 'Der Computer malt …';
    final who = widget.mode == GameMode.twoPlayers ? '${p.name}: ' : '';
    final sel = _selected;
    if (sel == null) return '${who}Wähle eine Farbe';
    return '${who}Setze ${p.hand[sel].label} auf ein freies Feld';
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              _TopBar(
                level: widget.level,
                subtitle: widget.mode == GameMode.vsComputer
                    ? 'Level ${widget.level.number} · ${widget.difficulty.label}'
                    : 'Level ${widget.level.number}',
                onBack: () => Navigator.of(context).pop(),
                onRules: () => showRules(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++) ...[
                      if (i == 1) const SizedBox(width: 12),
                      Expanded(
                        child: _PlayerPanel(
                          state: _state,
                          index: i,
                          showMiniHand: i != _handOwner,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GameWidget(key: ObjectKey(_game), game: _game),
                    ),
                    if (_canLetComputerStart)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: BrushButton(
                            label: 'Computer fängt an',
                            onPressed: _letComputerStart,
                            color: WheelColor.purple,
                            seed: 11,
                            fontSize: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: AppText.hand(22, color: Inks.graphite),
              ),
              const SizedBox(height: 4),
              _HandRow(
                hand: _state.players[_handOwner].hand,
                player: _handOwner,
                selected: _selected,
                enabled: _humanTurn,
                onSelect: _select,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: WheelStrip(selected: _game.selectedColor),
              ),
            ],
          ),
          if (_showResult)
            Positioned.fill(
              child: _ResultOverlay(
                state: _state,
                onRestart: _restart,
                onNext:
                    widget.mode == GameMode.vsComputer &&
                        _state.winner == 0 &&
                        widget.level.number < levels.length
                    ? _nextLevel
                    : null,
                onLevels: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.level,
    required this.subtitle,
    required this.onBack,
    required this.onRules,
  });

  final Level level;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onRules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Levelauswahl',
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              children: [
                Text(subtitle, style: AppText.hand(18, color: Inks.graphite)),
                Text(level.name, style: AppText.title(26)),
              ],
            ),
          ),
          RoundIconButton(
            icon: Icons.question_mark_rounded,
            tooltip: 'Spielregeln',
            onPressed: onRules,
          ),
        ],
      ),
    );
  }
}

/// Ownership symbol: the same ring that marks the player's fields.
class OwnerMark extends StatelessWidget {
  const OwnerMark({super.key, required this.player, this.size = 22});

  final int player;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _OwnerMarkPainter(player)),
  );
}

class _OwnerMarkPainter extends CustomPainter {
  _OwnerMarkPainter(this.player);

  final int player;

  @override
  void paint(Canvas canvas, Size size) {
    Watercolor.ownerRing(
      canvas,
      size.center(Offset.zero),
      size.shortestSide * 0.36,
      player,
      9,
    );
  }

  @override
  bool shouldRepaint(_OwnerMarkPainter old) => old.player != player;
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.state,
    required this.index,
    required this.showMiniHand,
  });

  final GameState state;
  final int index;
  final bool showMiniHand;

  @override
  Widget build(BuildContext context) {
    final p = state.players[index];
    final active = !state.isOver && state.current == index;
    final ink = Inks.players[index];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: active
            ? ink.withValues(alpha: 0.035)
            : Inks.paper.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? ink.withValues(alpha: 0.55) : Inks.paperDeep,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OwnerMark(player: index, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.hand(22, color: ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${state.total(index)}', style: AppText.title(34)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${p.points} Punkte\n${state.ownedFields(index)} Felder',
                  maxLines: 2,
                  style: AppText.body(
                    11,
                    color: Inks.graphite,
                  ).copyWith(height: 1.25),
                ),
              ),
              if (showMiniHand)
                for (final c in p.hand)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: PaintedDisc(color: c, size: 15, seed: c.index + 70),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HandRow extends StatelessWidget {
  const _HandRow({
    required this.hand,
    required this.player,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final List<WheelColor> hand;
  final int player;
  final int? selected;
  final bool enabled;
  final ValueChanged<int> onSelect;

  static const _tilt = [-0.06, 0.015, 0.07];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < hand.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _HandCard(
                key: ValueKey('slot$i'),
                color: hand[i],
                seed: i * 17 + hand[i].index,
                tilt: _tilt[i % _tilt.length],
                ink: Inks.players[player],
                selected: selected == i,
                enabled: enabled,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    super.key,
    required this.color,
    required this.seed,
    required this.tilt,
    required this.ink,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final WheelColor color;
  final int seed;
  final double tilt;
  final Color ink;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Farbkarte ${color.label}',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            offset: Offset(0, selected ? -0.1 : 0.04),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: enabled ? 1 : 0.55,
              child: Transform.rotate(
                angle: selected ? 0 : tilt,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 88,
                  height: 118,
                  decoration: BoxDecoration(
                    color: Inks.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? ink.withValues(alpha: 0.8)
                          : Inks.paperDeep,
                      width: selected ? 2.2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Inks.ink.withValues(
                          alpha: selected ? 0.22 : 0.12,
                        ),
                        blurRadius: selected ? 16 : 6,
                        offset: Offset(0, selected ? 8 : 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, a) => ScaleTransition(
                          scale: CurvedAnimation(
                            parent: a,
                            curve: Curves.easeOutBack,
                          ),
                          child: FadeTransition(opacity: a, child: child),
                        ),
                        child: PaintedDisc(
                          key: ValueKey(color),
                          color: color,
                          size: 66,
                          seed: seed,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(color.label, style: AppText.hand(20)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.state,
    required this.onRestart,
    required this.onNext,
    required this.onLevels,
  });

  final GameState state;
  final VoidCallback onRestart;
  final VoidCallback? onNext;
  final VoidCallback onLevels;

  String get _headline {
    final w = state.winner;
    if (w == null) return 'Unentschieden';
    if (state.mode == GameMode.vsComputer) {
      return w == 0 ? 'Gewonnen!' : 'Knapp daneben';
    }
    return '${state.players[w].name} gewinnt!';
  }

  @override
  Widget build(BuildContext context) {
    final w = state.winner;
    final accent = w == null
        ? WheelColor.yellow
        : (w == 0 ? WheelColor.blue : WheelColor.orange);
    return ColoredBox(
      color: Inks.paper.withValues(alpha: 0.72),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Transform.scale(
            scale: 0.9 + 0.1 * t,
            child: Opacity(opacity: t.clamp(0, 1), child: child),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              color: Inks.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Inks.paperDeep),
              boxShadow: [
                BoxShadow(
                  color: Inks.ink.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  child: CustomPaint(
                    painter: BrushStrokePainter(accent.pigment, 21),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _headline,
                            maxLines: 1,
                            style: AppText.title(38),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(1.5),
                    1: FlexColumnWidth(),
                    2: FlexColumnWidth(),
                  },
                  children: [
                    TableRow(
                      children: [
                        const SizedBox(),
                        for (var i = 0; i < 2; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OwnerMark(player: i, size: 18),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    state.players[i].name,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.hand(
                                      20,
                                      color: Inks.players[i],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    _row('Punkte', (i) => state.players[i].points),
                    _row('Felder', state.ownedFields),
                    _row('Gesamt', state.total, strong: true),
                  ],
                ),
                const SizedBox(height: 22),
                if (onNext != null) ...[
                  BrushButton(
                    label: 'Nächstes Level',
                    color: WheelColor.green,
                    seed: 31,
                    fontSize: 26,
                    onPressed: onNext,
                  ),
                  const SizedBox(height: 8),
                ],
                BrushButton(
                  label: 'Nochmal',
                  color: WheelColor.yellow,
                  seed: 32,
                  fontSize: 26,
                  onPressed: onRestart,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onLevels,
                  child: Text(
                    'Zur Levelauswahl',
                    style: AppText.hand(20, color: Inks.graphite),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TableRow _row(String label, int Function(int) value, {bool strong = false}) {
    final style = strong ? AppText.title(28) : AppText.body(15);
    return TableRow(
      decoration: strong
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: Inks.paperDeep)),
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: strong
                ? AppText.title(22)
                : AppText.body(15, color: Inks.graphite),
          ),
        ),
        for (var i = 0; i < 2; i++)
          Text('${value(i)}', textAlign: TextAlign.right, style: style),
      ],
    );
  }
}
