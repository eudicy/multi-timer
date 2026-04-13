import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:multi_timer/timer_screen.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  testWidgets('TimerScreen is rendered', (WidgetTester tester) async {
    final player = MockAudioPlayer();
    when(() => player.dispose()).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: TimerScreen(player)));

    expect(find.byType(TimerScreen), findsOneWidget);
  });
}
