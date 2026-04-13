import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:multi_timer/constants.dart';
import 'package:multi_timer/session_data.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class TimerScreen extends StatefulWidget {
  const TimerScreen(this._player, {super.key});

  final AudioPlayer _player;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  bool _isCounting = false;
  double _progress = 0.0; // Progress from 0.0 to 1.0
  Timer? _progressTimer;

  late final List<SessionData> _sessions = kDebugMode
      ? [
          SessionData(16_000, 'release/ganzkoerperatmung.mp3', 8000),
          SessionData(16_000, 'release/atem-halten.mp3', 8700),
          SessionData(16_000, 'release/ganzkoerperatmung.mp3', 8000),
          SessionData(16_000, 'release/atem-halten.mp3', 8700),
          SessionData(16_000, 'release/ganzkoerperatmung.mp3', 8000),
          SessionData(17_000, 'release/wellenatmen.mp3', 9000),
          SessionData(13_000, 'release/nachspueren.mp3', 5600),
        ]
      : [
          SessionData(300_000, 'release/ganzkoerperatmung.mp3', 8000),
          SessionData(60_000, 'release/atem-halten.mp3', 8700),
          SessionData(300_000, 'release/ganzkoerperatmung.mp3', 8000),
          SessionData(60_000, 'release/atem-halten.mp3', 8700),
          SessionData(300_000, 'release/ganzkoerperatmung.mp3', 8000),
          SessionData(120_000, 'release/wellenatmen.mp3', 9000),
          SessionData(60_000, 'release/nachspueren.mp3', 5600),
        ];

  AudioPlayer get _player => widget._player;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  int _calculateTotalDuration() {
    return _sessions.fold(0, (sum, session) {
      return sum + session.durationMs;
    });
  }

  Future<void> _playAudioAndWait(String audioPath) async {
    // Stop any previous playback to ensure clean state
    await _player.stop();

    final completer = Completer<void>();

    // Set up listener BEFORE playing to avoid race condition
    final subscription = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await _player.play(AssetSource(audioPath));
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }

    await completer.future;
    await subscription.cancel();
  }

  Future<void> _runExerciseSequence() async {
    setState(() {
      _isCounting = true;
      _progress = 0.0;
    });

    final totalDuration = _calculateTotalDuration();
    debugPrint(
      'Total duration: ${totalDuration}ms (${(totalDuration / 1000).toStringAsFixed(1)}s)',
    );
    final startTime = DateTime.now();

    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      setState(() {
        _progress = (elapsed / totalDuration).clamp(0.0, 1.0);
      });

      if (_progress >= 1.0) {
        timer.cancel();
      }
    });

    for (int i = 0; i < _sessions.length; i++) {
      SessionData session = _sessions[i];

      int remainingDurationMs = session.durationMs - kGongDurationMs;

      if (session.audioFile != null) {
        remainingDurationMs -= session.audioDurationMs;
        await _playAudioAndWait(session.audioFile!);
      }

      if (remainingDurationMs > 0) {
        await Future.delayed(Duration(milliseconds: remainingDurationMs));
      }

      await _playAudioAndWait(kGongAudioFile);
    }

    _progressTimer?.cancel();
    setState(() {
      _isCounting = false;
      _progress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCounting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Progress bar that fills from bottom to top
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: _progress,
                widthFactor: 1.0,
                child: Container(color: Colors.deepPurple.withOpacity(0.3)),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Multi Timer')),
      body: Center(
        child: ElevatedButton(
          onPressed: _runExerciseSequence,
          child: const Text('Start'),
        ),
      ),
    );
  }
}
