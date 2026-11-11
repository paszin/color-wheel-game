import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/color_wheel_game.dart';
import '../logic/game_state.dart';
import '../logic/tutorial.dart';
import '../model/board.dart';
import '../model/tutorial.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'widgets.dart';

/// Onboarding: fixed scenarios in which the player must place given colours
/// on given fields, one mechanism per step.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _step = 0;
  int _move = 0;
  late GameState _state;
  late ColorWheelGame _game;
  int? _selected;

  /// Correction after a wrong card or field; cleared by the next move.
  String? _hint;
  bool _stepDone = false;
  bool _finished = false;
  Timer? _timer;

  TutorialStep get _current => tutorialSteps[_step];
  TutorialMove? get _due =>
      _move < _current.moves.length ? _current.moves[_move] : null;
  bool get _humanTurn => _due != null && !_due!.byComputer;

  @override
  void initState() {
    super.initState();
    _loadStep(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadStep(int index) {
    _timer?.cancel();
    _step = index;
    _move = 0;
    _stepDone = false;
    _state = tutorialState(_current, index);
    _game = ColorWheelGame(state: _state, onNodeTap: _onNodeTap);
    _startMove();
  }

  /// Sets up the due move, or marks the step as done.
  void _startMove() {
    _selected = null;
    _hint = null;
    final move = _due;
    if (move == null) {
      _stepDone = true;
      // The player reads on; the computer is not about to move.
      _state.current = 0;
    } else {
      prepareTutorialMove(_state, move);
      if (move.byComputer) {
        _timer = Timer(const Duration(milliseconds: 1400), _computerMove);
      }
    }
    _syncGame();
  }

  void _syncGame() {
    final move = _due;
    _game
      ..interactive = _humanTurn
      ..hintNode = _humanTurn ? move!.node : null
      ..selectedColor = _selected == null || !_humanTurn
          ? null
          : _state.players[0].hand[_selected!];
  }

  void _select(int i) {
    if (!_humanTurn) return;
    final deselect = _selected == i;
    deselect ? Sound.deselect() : Sound.select();
    final want = _due!.color;
    setState(() {
      _selected = deselect ? null : i;
      _hint = deselect || _state.players[0].hand[i] == want
          ? null
          : 'Diesmal brauchst du ${want.label}.';
      _syncGame();
    });
  }

  void _onNodeTap(ColorNode node) {
    final move = _due;
    if (!_humanTurn || !node.isEmpty) return;
    final sel = _selected;
    String? hint;
    if (sel == null) {
      hint = 'Wähle zuerst ${move!.color.label} aus deiner Hand.';
    } else if (_state.players[0].hand[sel] != move!.color) {
      hint =
          'Nimm ${move.color.label} – nicht ${_state.players[0].hand[sel].label}.';
    } else if (node.id != move.node) {
      hint = 'Lege die Karte auf das leuchtende Feld.';
    }
    if (hint != null) {
      Sound.deselect();
      setState(() => _hint = hint);
      return;
    }
    _play();
  }

  void _computerMove() {
    if (!mounted) return;
    _play();
  }

  void _play() {
    final move = _due!;
    final player = move.byComputer ? 1 : 0;
    final result = playTutorialMove(_state, move);
    _game.showMove(result, player);
    setState(() {
      _move++;
      _selected = null;
      _hint = null;
      _game
        ..interactive = false
        ..hintNode = null
        ..selectedColor = null;
    });
    // Let the scoring animation play before the next instruction.
    final wait = 700 + result.events.length * 450;
    _timer = Timer(Duration(milliseconds: wait), () {
      if (mounted) setState(_startMove);
    });
  }

  void _next() {
    Sound.page();
    if (_step + 1 < tutorialSteps.length) {
      setState(() => _loadStep(_step + 1));
    } else {
      Sound.win();
      setState(() => _finished = true);
    }
  }

  void _restartStep() => setState(() => _loadStep(_step));

  String get _instruction {
    if (_stepDone) return _current.done;
    return _due!.prompt;
  }

  String get _status {
    if (_hint != null) return _hint!;
    final move = _due;
    if (move == null) return '';
    if (move.byComputer) return 'Der Computer malt …';
    if (_selected == null) return 'Wähle ${move.color.label}';
    return 'Setze ${move.color.label} auf das leuchtende Feld';
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              _TutorialBar(
                step: _step,
                title: _current.title,
                onBack: () => Navigator.of(context).pop(),
                onRestart: _restartStep,
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
                          showMiniHand: i == 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _InstructionCard(
                  key: ValueKey('$_step/$_stepDone/$_move'),
                  text: _instruction,
                  done: _stepDone,
                ),
              ),
              Expanded(
                child: GameWidget(key: ObjectKey(_game), game: _game),
              ),
              SizedBox(
                height: 44,
                child: Center(
                  child: _stepDone
                      ? BrushButton(
                          label: _step + 1 < tutorialSteps.length
                              ? 'Weiter'
                              : 'Fertig',
                          onPressed: _next,
                          color: WheelColor.green,
                          seed: 41,
                          fontSize: 22,
                        )
                      : Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: AppText.hand(
                            22,
                            color: _hint != null
                                ? WheelColor.red.deep
                                : Inks.graphite,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              HandRow(
                hand: _state.players[0].hand,
                player: 0,
                selected: _selected,
                enabled: _humanTurn,
                onSelect: _select,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: WheelStrip(
                  selected: _game.selectedColor,
                  wheel: _current.wheel,
                ),
              ),
            ],
          ),
          if (_finished)
            Positioned.fill(
              child: _FinishOverlay(
                onPlay: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const LevelSelectScreen(mode: GameMode.vsComputer),
                  ),
                ),
                onMenu: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TutorialBar extends StatelessWidget {
  const _TutorialBar({
    required this.step,
    required this.title,
    required this.onBack,
    required this.onRestart,
  });

  final int step;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Zum Menü',
            onPressed: onBack,
          ),
          // Balances the two buttons on the right so the title stays centred.
          const SizedBox(width: 52),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Tutorial · ${step + 1} von ${tutorialSteps.length}',
                  style: AppText.hand(18, color: Inks.graphite),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title, style: AppText.title(26)),
                ),
              ],
            ),
          ),
          RoundIconButton(
            icon: Icons.replay_rounded,
            tooltip: 'Schritt neu starten',
            onPressed: onRestart,
          ),
          const SizedBox(width: 4),
          const SoundButton(),
        ],
      ),
    );
  }
}

/// The explanation of the current move or the finished step.
class _InstructionCard extends StatelessWidget {
  const _InstructionCard({super.key, required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final accent = done ? WheelColor.green : WheelColor.blue;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        // Room for four lines, so the board rarely jumps when the text changes.
        constraints: const BoxConstraints(maxWidth: 520, minHeight: 108),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: accent.wash.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.pigment.withValues(alpha: 0.45)),
        ),
        child: Text(text, style: AppText.body(15)),
      ),
    );
  }
}

class _FinishOverlay extends StatelessWidget {
  const _FinishOverlay({required this.onPlay, required this.onMenu});

  final VoidCallback onPlay;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Inks.paper.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          constraints: const BoxConstraints(maxWidth: 420),
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
              const ColorWheelEmblem(size: 110),
              const SizedBox(height: 12),
              Text('Geschafft!', style: AppText.title(40)),
              const SizedBox(height: 8),
              Text(
                'Du kennst jetzt alle Regeln. Zeit für eine echte Partie '
                'gegen den Computer.',
                textAlign: TextAlign.center,
                style: AppText.body(15),
              ),
              const SizedBox(height: 20),
              BrushButton(
                label: 'Gegen den Computer',
                color: WheelColor.blue,
                seed: 42,
                fontSize: 24,
                onPressed: onPlay,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onMenu,
                child: Text(
                  'Zum Menü',
                  style: AppText.hand(20, color: Inks.graphite),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
