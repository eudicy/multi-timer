import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'timer_screen.dart';

void main() {
  runApp(const MultiTimerApp());
}

class MultiTimerApp extends StatelessWidget {
  const MultiTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: TimerScreen(AudioPlayer()),
    );
  }
}
