import 'package:bloc/bloc.dart';
import 'package:qunderlist/blocs/repeated/repeated_events.dart';
import 'package:qunderlist/blocs/repeated/repeated_states.dart';
import 'package:qunderlist/repository/models.dart';

class RepeatedBloc extends Bloc<RepeatedEvent, RepeatedState> {
  DateTime _dueDate;
  Repeated _repeated;
  bool _allowAutoComplete;
  bool _valid;
  Map<RepeatedStepSize,RepeatedStep> _steps;

  RepeatedBloc({DateTime dueDate, Repeated initial}): this._repeated(dueDate ?? _defaultDueDate(), initial ?? _defaultRepeated());
  RepeatedBloc._repeated(DateTime dueDate, Repeated repeated): this._internal(dueDate, repeated, _isAutoCompleteAllowed(repeated));
  RepeatedBloc._internal(DateTime dueDate, Repeated repeated, bool allowAutoComplete):
        _dueDate = dueDate,
        _repeated = repeated,
        _allowAutoComplete = allowAutoComplete,
        _valid = true,
        super(RepeatedState(repeated, allowAutoComplete, true))
  {
    _steps = {
      RepeatedStepSize.daily: _repeated.step is RepeatedStepDaily ? _repeated.step : RepeatedStepDaily(1),
      RepeatedStepSize.weekly: _repeated.step is RepeatedStepWeekly ? _repeated.step : RepeatedStepWeekly(1),
      RepeatedStepSize.monthly: _repeated.step is RepeatedStepMonthly ? _repeated.step : RepeatedStepMonthly(1, _dueDate.day),
      RepeatedStepSize.yearly: _repeated.step is RepeatedStepYearly ? _repeated.step : RepeatedStepYearly(1, _dueDate.month, _dueDate.day),
    };
  }

  @override
  Stream<RepeatedState> mapEventToState(RepeatedEvent event) async* {
    if (event is RepeatedToggleActiveEvent) {
      yield* mapToggleActiveEventToState(event);
    } else if (event is RepeatedToggleAutoAdvanceEvent) {
      yield* mapToggleAutoAdvanceEventToState(event);
    } else if (event is RepeatedToggleAutoCompleteEvent) {
      yield* mapToggleAutoCompleteEventToState(event);
    } else if (event is RepeatedToggleKeepHistoryEvent) {
      yield* mapToggleKeepHistoryEventToState(event);
    } else if (event is RepeatedSetAmountEvent) {
      yield* mapSetAmountEventToState(event);
    } else if (event is RepeatedSetStepSizeEvent) {
      yield* mapSetStepSizeEventToState(event);
    } else {
      throw "BUG: Unexpected event: $event";
    }
  }

  Stream<RepeatedState> mapToggleActiveEventToState(RepeatedToggleActiveEvent event) async* {
    _repeated = _repeated.copyWith(active: event.active);
    yield RepeatedState(_repeated, _allowAutoComplete, _valid);
  }

  Stream<RepeatedState> mapToggleAutoAdvanceEventToState(RepeatedToggleAutoAdvanceEvent event) async* {
    _repeated = _repeated.copyWith(autoAdvance: event.autoAdvance);
    _allowAutoComplete = event.autoAdvance;
    yield RepeatedState(_repeated, _allowAutoComplete, _valid);
  }

  Stream<RepeatedState> mapToggleAutoCompleteEventToState(RepeatedToggleAutoCompleteEvent event) async* {
    assert(_allowAutoComplete);
    _repeated = _repeated.copyWith(autoComplete: event.autoComplete);
    yield RepeatedState(_repeated, _allowAutoComplete, _valid);
  }

  Stream<RepeatedState> mapToggleKeepHistoryEventToState(RepeatedToggleKeepHistoryEvent event) async* {
    _repeated = _repeated.copyWith(keepHistory: event.keepHistory);
    yield RepeatedState(_repeated, _allowAutoComplete, _valid);
  }

  Stream<RepeatedState> mapSetAmountEventToState(RepeatedSetAmountEvent event) async* {
    _repeated = _repeated.copyWith(step: _repeated.step.withAmount(event.amount));
    _valid = event.amount != null;
    yield RepeatedState(_repeated, _allowAutoComplete, _valid);
  }

  Stream<RepeatedState> mapSetStepSizeEventToState(RepeatedSetStepSizeEvent event) async* {
    var oldSize = _repeated.step.stepSize;
    if (event.stepSize == oldSize) {
      return;
    }
    _steps[oldSize] = _repeated.step;
    _repeated = _repeated.copyWith(step: _steps[event.stepSize].withAmount(_repeated.step.amount));
    yield RepeatedState(_repeated, _allowAutoComplete, _valid);
  }

  static _defaultDueDate() {
    var now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  static _defaultRepeated() {
    return Repeated(true, false, false, true, RepeatedStepDaily(1));
  }
  static _isAutoCompleteAllowed(Repeated repeated) {
    return repeated.autoAdvance;
  }
}