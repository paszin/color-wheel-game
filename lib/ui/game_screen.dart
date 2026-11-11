import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/color_wheel_game.dart';
import '../logic/advance.dart';
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

  /// Hides the name of a tapped painted field again (twelve-colour levels).
  Timer? _inspectTimer;

  /// Best own total on this level before the finished game (vs computer).
  int? _previousBest;

  /// Set when a lost game still lets the player open the next level.
  SkipReason? _skip;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _timer?.cancel();
    _state = GameState(widget.level, widget.mode);
    _game = ColorWheelGame(state: _state, onNodeTap: _onNodeTap);
    _clearInspected();
    _selected = null;
    _showResult = false;
    _previousBest = null;
    _skip = null;
    _syncGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inspectTimer?.cancel();
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
    final deselect = _selected == i;
    deselect ? Sound.deselect() : Sound.select();
    setState(() {
      _selected = deselect ? null : i;
      _syncGame();
    });
  }

  void _onNodeTap(ColorNode node) {
    if (_inspect(node)) return;
    final i = _selected;
    if (!_humanTurn || i == null || !node.isEmpty) return;
    _play(i, node);
  }

  bool get _canInspect => widget.level.wheel.length > ColorWheel.classic.length;

  /// Names the colour of a painted field on the board for a moment, since
  /// neighbouring tones look alike; tapping it again hides the name.
  /// Returns false for empty fields, which keep their usual meaning.
  bool _inspect(ColorNode node) {
    if (!_canInspect || node.isEmpty) return false;
    final again = _game.inspectedNode == node.id;
    _clearInspected();
    if (!again) {
      _game.inspectedNode = node.id;
      _inspectTimer = Timer(
        const Duration(milliseconds: 2500),
        _clearInspected,
      );
    }
    return true;
  }

  void _clearInspected() {
    _inspectTimer?.cancel();
    _inspectTimer = null;
    _game.inspectedNode = null;
  }

  void _play(int handIndex, ColorNode node) {
    final player = _state.current;
    _clearInspected();
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

  Future<void> _finish() async {
    if (!mounted) return;
    final state = _state;
    if (widget.mode == GameMode.vsComputer) {
      final level = widget.level.number;
      final mine = state.total(0), theirs = state.total(1);
      final won = state.winner == 0;
      final previousBest = await Progress.best(level);
      await Progress.submitBest(level, mine);
      final losses = await Progress.recordResult(level, won: won);
      final unlocks =
          won && level < levels.length && level >= await Progress.unlocked();
      if (won) await Progress.unlock(level + 1);
      if (!mounted || !identical(state, _state)) return;
      _previousBest = previousBest;
      _skip = won
          ? null
          : skipReason(mine: mine, theirs: theirs, lossesInRow: losses);
      won ? Sound.win() : Sound.lose();
      if (unlocks) Sound.unlockLevel(delay: 1.6);
    } else {
      state.winner == null ? Sound.lose() : Sound.win();
    }
    setState(() => _showResult = true);
  }

  bool get _hasNextLevel =>
      widget.mode == GameMode.vsComputer &&
      widget.level.number < levels.length &&
      (_state.winner == 0 || _skip != null);

  Future<void> _skipToNext() async {
    await Progress.unlock(widget.level.number + 1);
    if (mounted) _nextLevel();
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
                        child: PlayerPanel(
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
                child: GameWidget(key: ObjectKey(_game), game: _game),
              ),
              // Before the first move the button takes the status line's
              // place, so it never covers a field of a large board.
              SizedBox(
                height: 44,
                child: Center(
                  child: _canLetComputerStart && _selected == null
                      ? BrushButton(
                          label: 'Computer fängt an',
                          onPressed: _letComputerStart,
                          color: WheelColor.purple,
                          seed: 11,
                          fontSize: 20,
                        )
                      : Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: AppText.hand(22, color: Inks.graphite),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              HandRow(
                hand: _state.players[_handOwner].hand,
                player: _handOwner,
                selected: _selected,
                enabled: _humanTurn,
                onSelect: _select,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: WheelStrip(
                  selected: _game.selectedColor,
                  wheel: widget.level.wheel,
                ),
              ),
            ],
          ),
          if (_showResult)
            Positioned.fill(
              child: _ResultOverlay(
                state: _state,
                previousBest: _previousBest,
                skip: _skip,
                onRestart: _restart,
                onNext: !_hasNextLevel
                    ? null
                    : _state.winner == 0
                    ? _nextLevel
                    : _skipToNext,
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
          // Balances the two buttons on the right so the title stays centred.
          const SizedBox(width: 52),
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
          const SizedBox(width: 4),
          const SoundButton(),
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

/// Name, total, points and fields of one player.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    super.key,
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

/// The cards of one hand, the selected one lifted.
class HandRow extends StatelessWidget {
  const HandRow({
    super.key,
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

  static const _tilt = [-0.06, 0.015, 0.07, -0.03];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < hand.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hand.length > 3 ? 5 : 8,
              ),
              child: _HandCard(
                compact: hand.length > 3,
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
    this.compact = false,
  });

  /// Narrower card so four fit next to each other on a phone.
  final bool compact;
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
                  width: compact ? 76 : 88,
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
                          size: compact ? 58 : 66,
                          seed: seed,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(color.label, style: AppText.hand(20)),
                        ),
                      ),
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
    required this.previousBest,
    required this.skip,
    required this.onRestart,
    required this.onNext,
    required this.onLevels,
  });

  final GameState state;
  final int? previousBest;
  final SkipReason? skip;
  final VoidCallback onRestart;
  final VoidCallback? onNext;
  final VoidCallback onLevels;

  String get _headline {
    final w = state.winner;
    if (w == null) return 'Unentschieden';
    if (state.mode == GameMode.vsComputer) {
      if (w == 0) return 'Gewonnen!';
      return isCloseLoss(state.total(0), state.total(1))
          ? 'Knapp daneben'
          : 'Verloren';
    }
    return '${state.players[w].name} gewinnt!';
  }

  /// Own total compared with the best total before this game.
  String? get _bestLine {
    if (state.mode != GameMode.vsComputer) return null;
    final mine = state.total(0);
    final best = previousBest;
    if (best == null) return 'Dein erster Bestwert: $mine';
    if (mine > best) return 'Neuer Bestwert! Bisher: $best';
    return 'Dein Bestwert: $best';
  }

  String? get _skipLine => switch (skip) {
    SkipReason.closeLoss => 'Knapp verloren – du darfst trotzdem weiter.',
    SkipReason.manyLosses =>
      'Drei Partien ohne Sieg – du darfst trotzdem weiter.',
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final w = state.winner;
    final bestLine = _bestLine;
    final skipLine = onNext == null || w == 0 ? null : _skipLine;
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
                if (bestLine != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    bestLine,
                    textAlign: TextAlign.center,
                    style: AppText.hand(21, color: Inks.ink),
                  ),
                ],
                if (skipLine != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    skipLine,
                    textAlign: TextAlign.center,
                    style: AppText.body(14, color: Inks.graphite),
                  ),
                ],
                const SizedBox(height: 22),
                if (onNext != null) ...[
                  BrushButton(
                    label: w == 0 ? 'Nächstes Level' : 'Trotzdem weiter',
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
