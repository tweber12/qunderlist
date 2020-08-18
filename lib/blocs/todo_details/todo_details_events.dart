import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/models.dart';

abstract class TodoDetailsEvent with EquatableMixin {
  @override
  bool get stringify => true;
}

class UpdateTitleEvent extends TodoDetailsEvent {
  final String newTitle;
  UpdateTitleEvent(this.newTitle);

  @override
  List<Object> get props => [newTitle];
}

class ToggleCompletedEvent extends TodoDetailsEvent {
  @override
  List<Object> get props => [];
}

class UpdatePriorityEvent extends TodoDetailsEvent {
  final TodoPriority newPriority;
  UpdatePriorityEvent(this.newPriority);

  @override
  List<Object> get props => [newPriority];
}

class UpdateNoteEvent extends TodoDetailsEvent {
  final String newNote;
  UpdateNoteEvent(this.newNote);

  @override
  List<Object> get props => [newNote];
}

class UpdateDueDateEvent extends TodoDetailsEvent {
  final DateTime newDueDate;
  UpdateDueDateEvent(this.newDueDate);

  @override
  List<Object> get props => [newDueDate];
}

class UpdateRemindersEvent extends TodoDetailsEvent {
  final List<DateTime> newReminders;
  UpdateRemindersEvent(this.newReminders);

  @override
  List<Object> get props => newReminders;
}

class LoadItemEvent extends TodoDetailsEvent {
  @override
  List<Object> get props => [];
}

class AddToListEvent extends TodoDetailsEvent {
  final TodoList list;
  AddToListEvent(this.list);

  @override
  List<Object> get props => [list];
}

class RemoveFromListEvent extends TodoDetailsEvent {
  final int listId;
  RemoveFromListEvent(this.listId);

  @override
  List<Object> get props => [listId];
}

class MoveToListEvent extends TodoDetailsEvent {
  final int oldListId;
  final TodoList newList;
  MoveToListEvent(this.oldListId, this.newList);

  @override
  List<Object> get props => [oldListId,newList];
}

class CopyToListEvent extends TodoDetailsEvent {
  final int listId;
  CopyToListEvent(this.listId);

  @override
  List<Object> get props => [listId];
}

class DeleteEvent extends TodoDetailsEvent {
  @override
  List<Object> get props => [];
}