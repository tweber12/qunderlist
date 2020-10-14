import 'package:equatable/equatable.dart';
import 'package:qunderlist/blocs/cache.dart';

enum TodoPriority {
  high,
  medium,
  low,
  none,
}

abstract class TodoItemBase with Cacheable, EquatableMixin {
  final int id;
  final String todo;
  final TodoPriority priority;
  final String note;
  final DateTime dueDate;
  final DateTime createdOn;
  final DateTime completedOn;

  TodoItemBase(this.todo, this.createdOn, {this.id, this.completedOn, this.priority = TodoPriority.none, this.note, this.dueDate});

  bool get completed => completedOn!=null;

  int get nActiveReminders;

  RepeatedStatus get repeatedStatus;

  @override
  List<Object> get props => [id, todo, note, createdOn, completedOn, priority, dueDate];

  @override
  int get cacheId => id;

  TodoItemShort shorten() {
    return TodoItemShort(
        todo, createdOn, id: id, priority: priority, note: note, dueDate: dueDate, completedOn: completedOn, nActiveReminders: nActiveReminders, repeatedStatus: repeatedStatus
    );
  }
}

class TodoItemShort extends TodoItemBase {
  final int _nActiveReminders;
  final RepeatedStatus _repeatedStatus;

  TodoItemShort(String title, DateTime createdOn, {int id, DateTime completedOn, TodoPriority priority = TodoPriority.none, String note, DateTime dueDate, int nActiveReminders=0, RepeatedStatus repeatedStatus = RepeatedStatus.none}):
      _repeatedStatus = repeatedStatus,
      _nActiveReminders = nActiveReminders,
      super(title, createdOn, id: id, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate);

  @override
  int get nActiveReminders => _nActiveReminders;

  @override
  RepeatedStatus get repeatedStatus => _repeatedStatus;

  @override
  List<Object> get props => [...super.props, _nActiveReminders, _repeatedStatus];

  TodoItemShort copyWith({int id, String todo, TodoPriority priority, DateTime createdOn, Nullable<String> note, Nullable<DateTime> dueDate, Nullable<DateTime> completedOn, int nActiveReminders, RepeatedStatus repeatedStatus}) {
    return TodoItemShort(
      todo ?? this.todo,
      createdOn ?? this.createdOn,
      id: id ?? this.id,
      priority: priority ?? this.priority,
      note: copyNullable(note, this.note),
      dueDate: copyNullable(dueDate, this.dueDate),
      completedOn: copyNullable(completedOn, this.completedOn),
      nActiveReminders: nActiveReminders ?? _nActiveReminders,
      repeatedStatus: repeatedStatus ?? this.repeatedStatus,
    );
  }

  TodoItemShort toggleCompleted() {
    if (completed) {
      return copyWith(completedOn: Nullable(null));
    } else {
      return copyWith(completedOn: Nullable(DateTime.now()));
    }
  }

  @override
  TodoItemShort shorten() {
    return this;
  }
}

class TodoItem extends TodoItemBase {
  final List<Reminder> reminders;
  final List<TodoList> onLists;
  final Repeated repeated;

  TodoItem(String title, DateTime createdOn, {int id, DateTime completedOn, TodoPriority priority = TodoPriority.none, String note, DateTime dueDate, List<Reminder> reminders, List<TodoList> onLists, Repeated repeated}):
        this.reminders = reminders ?? [],
        this.onLists = onLists ?? [],
        this.repeated = repeated,
        super(title, createdOn, id: id, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate);

  @override
  int get cacheId => id;

  @override
  int get nActiveReminders {
    var now = DateTime.now();
    return reminders.where((element) => element.at.isAfter(now)).length;
  }

  @override
  RepeatedStatus get repeatedStatus {
    if (repeated == null) {
      return RepeatedStatus.none;
    } else if (repeated.active) {
      return RepeatedStatus.active;
    } else {
      return RepeatedStatus.inactive;
    }
  }

  TodoItem copyWith({int id, String todo, TodoPriority priority, DateTime createdOn, Nullable<String> note, Nullable<DateTime> dueDate, Nullable<DateTime> completedOn, List<Reminder> reminders, List<TodoList> onLists, Nullable<Repeated> repeated}) {
    return TodoItem(
      todo ?? this.todo,
      createdOn ?? this.createdOn,
      id: id ?? this.id,
      priority: priority ?? this.priority,
      note: copyNullable(note, this.note),
      dueDate: copyNullable(dueDate, this.dueDate),
      completedOn: copyNullable(completedOn, this.completedOn),
      reminders: reminders ?? this.reminders,
      onLists: onLists ?? this.onLists,
      repeated: copyNullable(repeated, this.repeated),
    );
  }

  TodoItem toggleCompleted() {
    if (completed) {
      return copyWith(completedOn: Nullable(null));
    } else {
      return copyWith(completedOn: Nullable(DateTime.now()));
    }
  }

  @override
  List<Object> get props => [...super.props, ...reminders, onLists, repeated];
}

class Nullable<T> {
  final T value;
  Nullable(this.value);
}
T copyNullable<T>(Nullable<T> newValue, T oldValue) {
  if (newValue == null) {
    return oldValue;
  } else {
    return newValue.value;
  }
}

enum TodoStatusFilter {
  all,
  active,
  completed,
  important,
  withDueDate,
}

enum TodoListOrdering {
  custom,
  alphabetical,
  byDate,
}
enum TodoListOrderingDirection {
  ascending,
  descending,
}

enum Palette {
  pink,
  red,
  deepOrange,
  orange,
  amber,
  yellow,
  lime,
  lightGreen,
  green,
  teal,
  cyan,
  lightBlue,
  blue,
  indigo,
  purple,
  deepPurple,
  blueGrey,
  brown,
  grey,
}

class TodoList with EquatableMixin, Cacheable {
  final int id;
  final String listName;
  final Palette color;

  TodoList(this.listName, this.color, {this.id});

  @override
  List<Object> get props => [id, color, listName];

  @override
  int get cacheId => id;

  TodoList withId(int id) {
    assert(this.id == null);
    return TodoList(listName, color, id: id);
  }
}

class Reminder with EquatableMixin {
  final int id;
  final DateTime at;

  Reminder(this.at, {this.id});

  @override
  List<Object> get props => [id, at];

  Reminder withId(int id) {
    return Reminder(at, id: id);
  }
  Reminder copyWith({DateTime at}) {
    return Reminder(
      at ?? this.at,
      id: this.id,
    );
  }
}

enum RepeatedStatus {
  none,
  active,
  inactive,
}

class Repeated with EquatableMixin {
  final bool active;
  final bool autoAdvance;
  final bool autoComplete;
  final bool keepHistory;
  final RepeatedStep step;

  Repeated(this.active, this.autoAdvance, this.autoComplete, this.keepHistory, this.step);

  Repeated copyWith({bool active, bool autoAdvance, bool autoComplete, bool keepHistory, RepeatedStep step}) {
    return Repeated(
      active ?? this.active,
      autoAdvance ?? this.autoAdvance,
      autoComplete ?? this.autoComplete,
      keepHistory ?? this.keepHistory,
      step ?? this.step,
    );
  }

  @override
  List<Object> get props => [active, autoAdvance, autoComplete, keepHistory, step];
}

enum RepeatedStepSize {
  daily,
  weekly,
  monthly,
  yearly,
}

abstract class RepeatedStep with EquatableMixin {
  RepeatedStepSize get stepSize;
  int get amount;
  RepeatedStep withAmount(int amount);
}

class RepeatedStepDaily extends RepeatedStep {
  final int nDays;
  RepeatedStepDaily(this.nDays);

  RepeatedStepSize get stepSize => RepeatedStepSize.daily;
  int get amount => nDays;

  RepeatedStepDaily withAmount(int nDays) {
    return RepeatedStepDaily(nDays);
  }

  @override
  List<Object> get props => [nDays];
}

class RepeatedStepWeekly extends RepeatedStep {
  final int nWeeks;
  RepeatedStepWeekly(this.nWeeks);

  RepeatedStepSize get stepSize => RepeatedStepSize.weekly;
  int get amount => nWeeks;

  RepeatedStepWeekly withAmount(int nWeeks) {
    return RepeatedStepWeekly(nWeeks);
  }

  @override
  List<Object> get props => [nWeeks];
}

class RepeatedStepMonthly extends RepeatedStep {
  final int nMonths;
  final int day;
  RepeatedStepMonthly(this.nMonths, this.day);

  RepeatedStepSize get stepSize => RepeatedStepSize.monthly;
  int get amount => nMonths;

  RepeatedStepMonthly withAmount(int nMonths) {
    return RepeatedStepMonthly(nMonths, day);
  }

  @override
  List<Object> get props => [nMonths, day];
}

class RepeatedStepYearly extends RepeatedStep {
  final int nYears;
  final int month;
  final int day;
  RepeatedStepYearly(this.nYears, this.month, this.day);

  RepeatedStepSize get stepSize => RepeatedStepSize.yearly;
  int get amount => nYears;

  RepeatedStepYearly withAmount(int nYears) {
    return RepeatedStepYearly(nYears, month, day);
  }

  @override
  List<Object> get props => [nYears, month, day];
}