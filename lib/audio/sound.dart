import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/scoring.dart';

/// Background music and sound effects, with one switch for both.
///
/// Browsers only allow audio after a user gesture, so the music starts on the
/// first tap ([unlock]) rather than at app start.
class Sound {
  Sound._();

  static const _mutedKey = 'soundMuted';
  static const _musicVolume = 0.35;
  static const _sfxVolume = 0.7;

  /// Pentatonic kalimba notes in C major; a colour sequence climbs them.
  static const _scale = ['c4', 'd4', 'e4', 'g4', 'a4', 'c5', 'd5', 'e5'];

  /// True while sound is off. Off by default, persisted on this device.
  static final muted = ValueNotifier<bool>(true);

  static bool _started = false;

  /// Loads the mute setting and preloads the effects.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      muted.value = prefs.getBool(_mutedKey) ?? true;
    } catch (_) {}
    FlameAudio.bgm.initialize();
    unawaited(
      FlameAudio.audioCache
          .loadAll([
            'background.mp3',
            for (final n in _scale) 'sfx/note_$n.mp3',
            for (final s in [
              'click',
              'select',
              'deselect',
              'place',
              'place_ai',
              'secure',
              'spent',
              'full_wheel',
              'page',
              'win',
              'lose',
              'unlock',
            ])
              'sfx/$s.mp3',
          ])
          .catchError((_) => <Uri>[]),
    );
  }

  /// Starts the music on the first user gesture.
  static void unlock() {
    if (_started) return;
    _started = true;
    if (!muted.value) _playMusic();
  }

  static Future<void> toggleMuted() async {
    muted.value = !muted.value;
    if (muted.value) {
      await FlameAudio.bgm.pause();
    } else {
      // The tap on the switch is itself a user gesture.
      _started = true;
      _playMusic();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, muted.value);
    } catch (_) {}
  }

  static void _playMusic() {
    final bgm = FlameAudio.bgm;
    if (bgm.audioPlayer.state == PlayerState.paused) {
      bgm.resume();
    } else {
      bgm
          .play('background.mp3', volume: _musicVolume)
          .then((_) {}, onError: (_) {});
    }
  }

  static void _sfx(String name, {double volume = 1, double delay = 0}) {
    if (muted.value) return;
    void play() {
      if (muted.value) return;
      FlameAudio.play(
        'sfx/$name.mp3',
        volume: _sfxVolume * volume,
      ).then((_) {}, onError: (_) {});
    }

    if (delay <= 0) {
      play();
    } else {
      Timer(Duration(milliseconds: (delay * 1000).round()), play);
    }
  }

  static void click() => _sfx('click', volume: 0.6);
  static void select() => _sfx('select', volume: 0.7);
  static void deselect() => _sfx('deselect', volume: 0.6);
  static void page() => _sfx('page', volume: 0.7);
  static void win() => _sfx('win');
  static void lose() => _sfx('lose', volume: 0.8);
  static void unlockLevel({double delay = 0}) =>
      _sfx('unlock', volume: 0.6, delay: delay);

  /// Placement and scoring sounds of a move. [delays] are the start times of
  /// the score animations, one per event, in seconds.
  static void move(
    MoveResult result, {
    required bool byComputer,
    required List<double> delays,
  }) {
    _sfx(byComputer ? 'place_ai' : 'place', volume: byComputer ? 0.7 : 0.9);
    if (result.secures) _sfx('secure', volume: 0.35, delay: delays.first + 0.3);
    for (var i = 0; i < result.events.length; i++) {
      final e = result.events[i];
      final t = delays[i];
      switch (e.kind) {
        case ScoreKind.same:
          _sfx('note_e4', delay: t);
        case ScoreKind.complement:
          _sfx('note_c4', delay: t);
          _sfx('note_g4', delay: t);
        case ScoreKind.sequence:
          final steps = e.nodes.length.clamp(1, _scale.length);
          for (var s = 0; s < steps; s++) {
            _sfx('note_${_scale[s]}', volume: 0.85, delay: t + s * 0.09);
          }
        case ScoreKind.fullWheel:
          _sfx('full_wheel', delay: t);
          _sfx('spent', volume: 0.5, delay: t + 0.8);
      }
    }
  }
}
