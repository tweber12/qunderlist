import 'package:equatable/equatable.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/repository/repository.dart';

abstract class TodoListsStates with EquatableMixin {}

class TodoListsLoading extends TodoListsStates {
  @override
  List<Object> get props => [];
}

class TodoListsLoaded extends TodoListsStates {
  final ListCache<TodoList> lists;
  TodoListsLoaded(this.lists);

  @override
  List<Object> get props => [lists];
}

class TodoListsLoadingFailed extends TodoListsStates {
  @override
  List<Object> get props => [];
}