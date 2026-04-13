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
          SessionData(20_000, 'release/ganzkoerperatmung.mp3'),
          SessionData(20_000, 'release/atem-halten.mp3'),
          SessionData(20_000, 'release/ganzkoerperatmung.mp3'),
          SessionData(20_000, 'release/atem-halten.mp3'),
          SessionData(20_000, 'release/ganzkoerperatmung.mp3'),
          SessionData(20_000, 'release/wellenatmen.mp3'),
          SessionData(20_000, 'release/nachspueren.mp3'),
        ]
      : [
          SessionData(300_000, 'release/ganzkoerperatmung.mp3'),
          SessionData(60_000, 'release/atem-halten.mp3'),
          SessionData(300_000, 'release/ganzkoerperatmung.mp3'),
          SessionData(60_000, 'release/atem-halten.mp3'),
          SessionData(300_000, 'release/ganzkoerperatmung.mp3'),
          SessionData(120_000, 'release/wellenatmen.mp3'),
          SessionData(60_000, 'release/nachspueren.mp3'),
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

  Future<void> _play(String audioPath) async {
    await _player.stop();
    await _player.play(AssetSource(audioPath));
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

    for (final session in _sessions) {
      if (session.audioFile != null) {
        await _play(session.audioFile!);
      }

      int remainingDurationMs = session.durationMs - kGongDurationMs;
      if (remainingDurationMs > 0) {
        await Future.delayed(Duration(milliseconds: remainingDurationMs));
      }

      await _play(kGongAudioFile);
      await Future.delayed(const Duration(milliseconds: kGongDurationMs));
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
