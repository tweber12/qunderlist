import 'package:qunderlist/repository/repository.dart';
import 'package:equatable/equatable.dart';

abstract class TodoListsEvents with EquatableMixin {
  final int chunkFrom;
  final int chunkTo;
  final bool fromBottom;
  TodoListsEvents(this.chunkFrom, this.chunkTo, this.fromBottom): assert(chunkTo >= chunkFrom);


  @override
  List<Object> get props => [chunkFrom, chunkTo];

  @override
  bool get stringify => true;
}

class GetChunkEvent extends TodoListsEvents {
  GetChunkEvent(chunkFrom, chunkTo, {fromBottom: false}): super(chunkFrom, chunkTo, fromBottom);
}

class TodoListAddedEvent extends TodoListsEvents {
  final TodoList list;
  TodoListAddedEvent(chunkFrom, chunkTo, this.list, {bool fromBottom: false}): super(chunkFrom, chunkTo, fromBottom);

  @override
  List<Object> get props => super.props+[list];
}

class TodoListDeletedEvent extends TodoListsEvents {
  final TodoList list;
  TodoListDeletedEvent(chunkFrom, chunkTo, this.list, {bool fromBottom: false}): super(chunkFrom, chunkTo, fromBottom);

  @override
  List<Object> get props => super.props+[list];
}

class ReorderTodoListsEvent extends TodoListsEvents {
  final TodoList list;
  final int moveTo;
  ReorderTodoListsEvent(chunkFrom, chunkTo, this.list, this.moveTo, {bool fromBottom: false}): super(chunkFrom, chunkTo, fromBottom);

  @override
  List<Object> get props => super.props+[list,moveTo];
}