import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:multi_timer/timer_screen.dart';
import 'package:multi_timer/constants.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  const kSessionDurationMs = 20_000;
  const kExerciseDurationMs = 140_000;
  late MockAudioPlayer player;

  setUpAll(() {
    registerFallbackValue(AssetSource(''));
  });

  setUp(() {
    player = MockAudioPlayer();
    when(() => player.dispose()).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.play(any())).thenAnswer((_) async {});
  });

  void expectPlayerReceivedInOrder(List<String> audioFilePaths) {
    final captured = verify(() => player.play(captureAny())).captured;
    expect(captured.length, equals(audioFilePaths.length));
    for (var i = 0; i < audioFilePaths.length; i++) {
      expect(
        captured[i],
        isA<AssetSource>().having((a) => a.path, 'path', audioFilePaths[i]),
      );
    }
  }

  testWidgets('plays gong after first session delay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: TimerScreen(player)));

    await tester.tap(find.text('Start'));

    // Wait until gong started playing
    const int gongPlaybackStartMs = kSessionDurationMs - kGongDurationMs;
    await tester.pump(const Duration(milliseconds: gongPlaybackStartMs));

    expectPlayerReceivedInOrder(['release/ganzkoerperatmung.mp3', kGongAudioFile]);

    // drain all pending timers
    const int remainingExerciseDurationMs = kExerciseDurationMs - gongPlaybackStartMs;
    await tester.pump(const Duration(milliseconds: remainingExerciseDurationMs));
  });

  testWidgets('returns to idle state after full sequence completes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: TimerScreen(player)));

    await tester.tap(find.text('Start'));

    // Wait for full sequence to end
    await tester.pump(const Duration(milliseconds: kExerciseDurationMs));

    // Verify start button is visible
    expect(find.text('Start'), findsOneWidget);
  });
}
