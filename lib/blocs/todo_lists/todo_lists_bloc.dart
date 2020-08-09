import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:qunderlist/blocs/todo_lists/todo_lists_events.dart';
import 'package:qunderlist/blocs/todo_lists/todo_lists_states.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoListsBloc<R extends TodoRepository> extends Bloc<TodoListsEvents, TodoListsStates> {
  R _repository;
  Future<int> _numberOfLists;
  TodoListsBloc(repository): _repository=repository, _numberOfLists = repository.getNumberOfTodoLists(), super(TodoListsLoading());
  int lastFrom = 0;
  int lastTo = 0;

  @override
  Stream<TodoListsStates> mapEventToState(TodoListsEvents event) async* {
    if (event is GetChunkEvent) {
      yield* _mapGetChunkEventToState(event);
    } else if (event is TodoListAddedEvent) {
      yield* _mapTodoListAddedEventToState(event);
    } else if (event is TodoListDeletedEvent) {
      yield* _mapTodoListDeletedEventToState(event);
    } else if (event is ReorderTodoListsEvent) {
      yield* _mapReorderTodoListsEventToState(event);
    }
  }

  Stream<TodoListsStates> _mapGetChunkEventToState(GetChunkEvent event) async* {
    yield* _loadChunk(event.chunkFrom, event.chunkTo, fromBottom: event.fromBottom);
  }

  Stream<TodoListsStates> _mapTodoListAddedEventToState(TodoListAddedEvent event) async* {
    var numberOfLists = await _numberOfLists;
    await _repository.addTodoList(event.list);
    _numberOfLists = Future.value(numberOfLists+1);
    yield* _loadChunk(event.chunkFrom, event.chunkTo, fromBottom: event.fromBottom);

  }

  Stream<TodoListsStates> _mapTodoListDeletedEventToState(TodoListDeletedEvent event) async* {
    print("Delete item");
    var numberOfLists = await _numberOfLists;
    await _repository.deleteTodoList(event.list);
    _numberOfLists = Future.value(numberOfLists-1);
    yield* _loadChunk(event.chunkFrom, event.chunkTo, fromBottom: event.fromBottom);
  }

  Stream<TodoListsStates> _mapReorderTodoListsEventToState(ReorderTodoListsEvent event) async* {
    // The database uses 1 based indices
    await _repository.moveList(event.list, event.moveTo+1);
    yield* _loadChunk(event.chunkFrom, event.chunkTo, fromBottom: event.fromBottom);
  }

  Stream<TodoListsStates> _loadChunk(int from, int to, {bool fromBottom: false}) async* {
    int numberOfLists = await _numberOfLists;
    if (numberOfLists == 0) {
      yield ChunkLoaded(Chunk(0, [], 0));
    }
    int fromNorm;
    int toNorm;
    if (!fromBottom) {
      fromNorm = from>=0 ? from : 0;
      toNorm = to;
    } else {
      fromNorm = numberOfLists-to;
      fromNorm = fromNorm >= 0 ? fromNorm : 0;
      toNorm = numberOfLists-from;
    }
    var fromFinal = min(fromNorm, lastFrom);
    var toFinal = max(toNorm, lastTo);
    print("$fromFinal, $toFinal <= $fromNorm, $toNorm");
    lastFrom = fromNorm;
    lastTo = toNorm;
    var chunk = await _repository.getTodoListsChunk(fromFinal, toFinal);
    yield ChunkLoaded(Chunk(fromFinal, chunk, numberOfLists));
  }
}