import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:multi_timer/timer_screen.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  setUpAll(() {
    registerFallbackValue(AssetSource(''));
  });

  testWidgets('plays instruction audio when Start is tapped', (
    WidgetTester tester,
  ) async {
    final player = MockAudioPlayer();
    when(() => player.dispose()).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.play(any())).thenAnswer((_) async {});

    // Render the TimerScreen
    await tester.pumpWidget(MaterialApp(home: TimerScreen(player)));

    // Tap the Start button
    await tester.tap(find.text('Start'));

    // Process the tap and any resulting state changes
    await tester.pump();

    // Verify that the first instruction audio is played
    final captured = verify(() => player.play(captureAny())).captured;
    expect(captured.length, equals(1));
    expect(
      captured.first,
      isA<AssetSource>().having(
        (a) => a.path,
        'path',
        'release/ganzkoerperatmung.mp3',
      ),
    );

    // drain all pending timers
    await tester.pump(const Duration(seconds: 140));

    // process final setState
    await tester.pump();
  });
}
