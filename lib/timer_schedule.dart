import 'package:multi_timer/main.dart';
import 'exercise_finished_event.dart';

class TimerSchedule {
  final List<SessionData> sessions;
  
  TimerSchedule(this.sessions);

  List<ExerciseFinishedEvent> buildEvents() {
    final exerciseDurationMs = sessions.fold(0, (sum, session) => sum + session.durationSeconds * 1000);
    return [
      ExerciseFinishedEvent(offsetMs: exerciseDurationMs),
    ];
  }
}