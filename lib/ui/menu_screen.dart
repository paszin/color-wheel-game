import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'level_select_screen.dart';
import 'rules_sheet.dart';
import 'tutorial_screen.dart';
import 'widgets.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _open(BuildContext context, GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LevelSelectScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final emblem = (constraints.maxHeight * 0.36).clamp(160.0, 300.0);
          final content = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Spacer(flex: 2),
                ColorWheelEmblem(size: emblem),
                const SizedBox(height: 28),
                Text('Farbkreis', style: AppText.title(56)),
                const SizedBox(height: 6),
                Text(
                  'Ein Legespiel in Aquarell',
                  style: AppText.hand(24, color: Inks.graphite),
                ),
                const Spacer(flex: 2),
                BrushButton(
                  label: 'Gegen den Computer',
                  color: WheelColor.blue,
                  seed: 11,
                  onPressed: () => _open(context, GameMode.vsComputer),
                ),
                const SizedBox(height: 14),
                BrushButton(
                  label: 'Zwei Spieler',
                  color: WheelColor.orange,
                  seed: 12,
                  onPressed: () => _open(context, GameMode.twoPlayers),
                ),
                const SizedBox(height: 14),
                BrushButton(
                  label: 'Tutorial',
                  color: WheelColor.purple,
                  seed: 14,
                  fontSize: 24,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TutorialScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BrushButton(
                  label: 'Spielregeln',
                  color: WheelColor.green,
                  seed: 13,
                  fontSize: 24,
                  onPressed: () => showRules(context),
                ),
                const Spacer(),
              ],
            ),
          );
          return Stack(
            children: [
              Positioned.fill(child: content),
              const Positioned(top: 8, right: 8, child: SoundButton()),
            ],
          );
        },
      ),
    );
  }
}
