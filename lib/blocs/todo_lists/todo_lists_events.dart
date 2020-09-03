import 'package:qunderlist/repository/repository.dart';
import 'package:equatable/equatable.dart';

abstract class TodoListsEvents with EquatableMixin {
  @override
  bool get stringify => true;
}

class LoadTodoListsEvent extends TodoListsEvents {
  @override
  List<Object> get props => [];
}

class TodoListAddedEvent extends TodoListsEvents {
  final TodoList list;
  TodoListAddedEvent(this.list);

  @override
  List<Object> get props => [list];
}

class TodoListDeletedEvent extends TodoListsEvents {
  final int index;
  final TodoList list;
  TodoListDeletedEvent(this.list, this.index);

  @override
  List<Object> get props => [list];
}

class TodoListsReorderedEvent extends TodoListsEvents {
  final TodoList moveFrom;
  final int moveFromIndex;
  final TodoList moveTo;
  final int moveToIndex;
  TodoListsReorderedEvent(this.moveFrom, this.moveFromIndex, this.moveTo, this.moveToIndex);

  @override
  List<Object> get props => [moveFrom,moveTo,moveFromIndex,moveToIndex];
}

class ExternalUpdateEvent extends TodoListsEvents {
  @override
  List<Object> get props => [];
}