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

  @override
  List<Object> get props => [id, todo, note, createdOn, completedOn, priority, dueDate];

  @override
  int get cacheId => id;

  TodoItemShort shorten() {
    return TodoItemShort(
        todo, createdOn, id: id, priority: priority, note: note, dueDate: dueDate, completedOn: completedOn, nActiveReminders: nActiveReminders
    );
  }
}

class TodoItemShort extends TodoItemBase {
  final int _nActiveReminders;

  TodoItemShort(String title, DateTime createdOn, {int id, DateTime completedOn, TodoPriority priority = TodoPriority.none, String note, DateTime dueDate, int nActiveReminders=0}):
      _nActiveReminders = nActiveReminders,
      super(title, createdOn, id: id, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate);

  @override
  int get nActiveReminders => _nActiveReminders;

  @override
  List<Object> get props => [...super.props, _nActiveReminders];

  TodoItemShort copyWith({int id, String todo, TodoPriority priority, DateTime createdOn, Nullable<String> note, Nullable<DateTime> dueDate, Nullable<DateTime> completedOn, int nActiveReminders}) {
    return TodoItemShort(
      todo ?? this.todo,
      createdOn ?? this.createdOn,
      id: id ?? this.id,
      priority: priority ?? this.priority,
      note: copyNullable(note, this.note),
      dueDate: copyNullable(dueDate, this.dueDate),
      completedOn: copyNullable(completedOn, this.completedOn),
      nActiveReminders: nActiveReminders ?? _nActiveReminders,
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

  TodoItem(String title, DateTime createdOn, {int id, DateTime completedOn, TodoPriority priority = TodoPriority.none, String note, DateTime dueDate, List<Reminder> reminders, List<TodoList> onLists}):
        this.reminders = reminders ?? [],
        this.onLists = onLists ?? [],
        super(title, createdOn, id: id, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate);

  @override
  int get cacheId => id;

  @override
  int get nActiveReminders {
    var now = DateTime.now();
    return reminders.where((element) => element.at.isAfter(now)).length;
  }

  TodoItem copyWith({int id, String todo, TodoPriority priority, DateTime createdOn, Nullable<String> note, Nullable<DateTime> dueDate, Nullable<DateTime> completedOn, List<Reminder> reminders, List<TodoList> onLists}) {
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
  List<Object> get props => [...super.props, ...reminders, onLists];
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