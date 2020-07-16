import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/repository.dart';

abstract class TodoListsStates with EquatableMixin {}

class TodoListsLoading extends TodoListsStates {
  @override
  List<Object> get props => [];
}

class ChunkLoaded extends TodoListsStates {
  final Chunk<TodoList> chunkOfLists;
  ChunkLoaded(this.chunkOfLists);

  @override
  List<Object> get props => [chunkOfLists];
}

class ChunkLoadFailed extends TodoListsStates {
  @override
  List<Object> get props => [];
}