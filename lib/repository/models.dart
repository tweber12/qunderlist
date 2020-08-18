import 'package:equatable/equatable.dart';

enum TodoPriority {
  high,
  medium,
  low,
  none,
}

class TodoItem {
  final int id;
  final String todo;
  final bool completed;
  final TodoPriority priority;
  final String note;
  final DateTime dueDate;
  final DateTime createdOn;
  final DateTime completedOn;
  final List<DateTime> reminders;

  TodoItem(this.todo, this.createdOn, {this.id, this.completed = false, this.completedOn, this.priority = TodoPriority.none, this.note, this.dueDate, reminders}):
      this.reminders = reminders ?? [];

  TodoItem copyWith({int id, String todo, bool completed, TodoPriority priority, String note, DateTime dueDate, DateTime createdOn, DateTime completedOn, List<DateTime> reminders, bool deleteDueDate=false, bool setCompletedOn=false}) {
    return TodoItem(
      todo ?? this.todo,
      createdOn ?? this.createdOn,
      id: id ?? this.id,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      note: note ?? this.note,
      dueDate: dueDate!=null || deleteDueDate ? dueDate : this.dueDate,
      completedOn: completedOn!=null || setCompletedOn ? completedOn : this.completedOn,
      reminders: reminders ?? this.reminders,
    );
  }

  TodoItem toggleCompleted() {
    if (completed) {
      return this.copyWith(completed: false, completedOn: null, setCompletedOn: true);
    } else {
      return this.copyWith(completed: true, completedOn: DateTime.now());
    }
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

class TodoList with EquatableMixin {
  final int id;
  final String listName;

  TodoList(this.listName, {this.id});

  @override
  List<Object> get props => [id, listName];
}

class Chunk<T> with EquatableMixin {
  final int start;
  final int end;
  final int totalLength;
  final List<T> data;
  Chunk(this.start, this.data, this.totalLength): end = start + data.length;

  @override
  List<Object> get props => [start, end, data];

  bool contains(int index) {
    return start <= index && end > index;
  }
  T get(int index, {bool relative: false}) {
    var i = relative ? index : index-start;
    return data[i];
  }
}