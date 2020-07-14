import 'package:qunderlist/repository/repository.dart';
import 'package:equatable/equatable.dart';

abstract class TodoListsEvents with EquatableMixin {
  @override
  bool get stringify => true;
}

class LoadTodoLists extends TodoListsEvents {
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
  final TodoList list;
  TodoListDeletedEvent(this.list);

  @override
  List<Object> get props => [list];
}

class ReorderTodoListsEvent extends TodoListsEvents {
  final TodoList list;
  final int moveTo;
  ReorderTodoListsEvent(this.list, this.moveTo);

  @override
  List<Object> get props => [list, moveTo];
}