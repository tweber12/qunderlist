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

TodoItem nextItem(TodoItem previous) {
  var dueDate = _nextDueDate(previous.dueDate, previous.repeated);
  var reminders = previous.reminders.map((r) => Reminder(_nextReminder(r.at, dueDate, previous.dueDate))).toList();
  return previous.copyWith(createdOn: DateTime.now(), completedOn: Nullable(null), dueDate: Nullable(dueDate), reminders: reminders, newItem: true);
}

DateTime _nextDueDate(DateTime dueDate, Repeated repeated) {
  switch (repeated.step.stepSize) {
    case RepeatedStepSize.daily: return _nextDateDaily(dueDate, repeated.step);
    case RepeatedStepSize.weekly: return _nextDateWeekly(dueDate, repeated.step);
    case RepeatedStepSize.monthly: return _nextDateMonthly(dueDate, repeated.step);
    case RepeatedStepSize.yearly: return _nextDateYearly(dueDate, repeated.step);
  }
  throw "BUG: Unhandled step size";
}

DateTime _nextReminder(DateTime reminderDate, DateTime nextDueDate, DateTime previousDueDate) {
  // The way the difference is computed is a bit unintuitive, especially the signs in front of the timeZoneOffsets
  // What we want for this function is the difference in days between the two due dates
  // The only safe way to do that is to ignore any changes in timezones, because otherwise the difference in hours between two days can change
  // For this compute the difference between the dates in UTC (not the same points in time, i.e. instead of 2020-03-10T00:00 (localtime) use 2020-03-10T00:00 (UTC))
  // To convert between these dates, the timeZoneOffset has to be added to the local time
  // Example for timeZoneOffset = 1:
  //    2020-03-10T00:00 (localtime) == 2020-03-09T23:00 (UTC)
  // => 2020-03-10T00:00 (localtime) + timeZoneOffset == 2020-03-10T01:00 (localtime) == 2020-03-10T00:00 (UTC)
  // Example dst change timeZoneOffset = 1 (Change on 2020-03-29T02:00 to timeZoneOffset = 2):
  //    Difference between 2020-03-29T00:00 (localtime) and 2020-03-30T00:00 (localtime) should be one day
  //    2020-03-29T00:00 (localtime) == 2020-03-28T23:00 (UTC)
  //    2020-03-30T00:00 (localtime) == 2020-03-29T22:00 (UTC)
  //    nextDueDate.difference(previousDueDate) + nextDueDate.timeZoneOffset - previousDueDate.timeZoneOffset; == 24h == 1d
  //    (               == 23h                )   (         == 2h          )   (          == 1h             )
  var difference = nextDueDate.difference(previousDueDate) + nextDueDate.timeZoneOffset - previousDueDate.timeZoneOffset;
  var next =  DateTime(reminderDate.year, reminderDate.month, reminderDate.day + difference.inDays, reminderDate.hour, reminderDate.minute);
  return next;
}

DateTime _nextDateDaily(DateTime date, RepeatedStepDaily step) {
  return DateTime(date.year, date.month, date.day + step.nDays, date.hour, date.minute);
}

DateTime _nextDateWeekly(DateTime date, RepeatedStepWeekly step) {
  return DateTime(date.year, date.month, date.day + step.nWeeks * DateTime.daysPerWeek, date.hour, date.minute);
}

DateTime _nextDateMonthly(DateTime date, RepeatedStepMonthly step) {
  var next = DateTime(date.year, date.month + step.nMonths, step.day, date.hour, date.minute);
  if (next.day != step.day) {
    // We must have rolled over into the next month because the current month doesn't have enough days
    // In that case the amount of days beyond the end of the month is given by how far we rolled over
    next = DateTime(date.year, date.month + step.nMonths, step.day - next.day, date.hour, date.minute);
  }
  return next;
}

DateTime _nextDateYearly(DateTime date, RepeatedStepYearly step) {
  var next = DateTime(date.year + step.nYears, step.month, step.day, date.hour, date.minute);
  if (next.month != step.month) {
    // We again rolled over into the next month. The only case where that happens (that I can think of)
    // is when the original date was February 29th and a year later we end up on March 1st.
    if (step.month == DateTime.february && step.day == 29) {
      next = DateTime(date.year + step.nYears, step.month, step.day-1, date.hour, date.minute);
    }
  }
  return next;
}