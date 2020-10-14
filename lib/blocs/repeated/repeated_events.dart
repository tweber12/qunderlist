import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/models.dart';

abstract class RepeatedEvent with EquatableMixin {}

class RepeatedToggleActiveEvent extends RepeatedEvent {
  final bool active;
  RepeatedToggleActiveEvent(this.active);

  @override
  List<Object> get props => [active];
}

class RepeatedToggleAutoAdvanceEvent extends RepeatedEvent {
  final bool autoAdvance;
  RepeatedToggleAutoAdvanceEvent(this.autoAdvance);

  @override
  List<Object> get props => [autoAdvance];
}

class RepeatedToggleAutoCompleteEvent extends RepeatedEvent {
  final bool autoComplete;
  RepeatedToggleAutoCompleteEvent(this.autoComplete);

  @override
  List<Object> get props => [autoComplete];
}

class RepeatedToggleKeepHistoryEvent extends RepeatedEvent {
  final bool keepHistory;
  RepeatedToggleKeepHistoryEvent(this.keepHistory);

  @override
  List<Object> get props => [keepHistory];
}

class RepeatedSetStepSizeEvent extends RepeatedEvent {
  final RepeatedStepSize stepSize;
  RepeatedSetStepSizeEvent(this.stepSize);

  @override
  List<Object> get props => [stepSize];
}

class RepeatedSetAmountEvent extends RepeatedEvent {
  final int amount;
  RepeatedSetAmountEvent(this.amount);

  @override
  List<Object> get props => [amount];
}
