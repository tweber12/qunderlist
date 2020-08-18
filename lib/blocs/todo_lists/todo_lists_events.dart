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
  final int moveFrom;
  final int moveTo;
  TodoListsReorderedEvent(this.moveFrom, this.moveTo);

  @override
  List<Object> get props => [moveFrom,moveTo];
}