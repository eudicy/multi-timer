import 'package:equatable/equatable.dart';

class ExerciseFinishedEvent extends Equatable {
  final int offsetMs;

  const ExerciseFinishedEvent({required this.offsetMs});

  @override
  List<Object?> get props => [offsetMs];
}
