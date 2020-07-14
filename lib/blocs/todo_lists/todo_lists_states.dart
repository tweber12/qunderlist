import 'package:equatable/equatable.dart';

abstract class TodoListsStates with EquatableMixin {}

class TodoListsLoading extends TodoListsStates {
  @override
  List<Object> get props => [];
}

class TodoListsLoaded extends TodoListsStates {
  final List<int> listOfLists;
  TodoListsLoaded(this.listOfLists);

  @override
  List<Object> get props => [listOfLists];
}

class TodoListsLoadFailed extends TodoListsStates {
  @override
  List<Object> get props => [];
}