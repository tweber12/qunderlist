import 'package:equatable/equatable.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/repository/repository.dart';

abstract class TodoListStates with EquatableMixin {
  @override
  bool get stringify => true;
}

class TodoListLoading extends TodoListStates {
  final TodoList list;
  TodoListLoading(this.list);

  @override
  List<Object> get props => [list];
}

class TodoListLoadingFailed extends TodoListStates {
  @override
  List<Object> get props => [];
}

class TodoListLoaded extends TodoListStates {
  final TodoList list;
  final ListCache<TodoItem> items;

  TodoListLoaded(this.list, this.items);

  @override
  List<Object> get props => [list, items];
}

class TodoListDeleted extends TodoListStates {
  @override
  List<Object> get props => [];
}