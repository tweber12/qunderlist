import 'package:bloc/bloc.dart';
import 'package:mutex/mutex.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/blocs/todo_lists/todo_lists_events.dart';
import 'package:qunderlist/blocs/todo_lists/todo_lists_states.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoListsBloc<R extends TodoRepository> extends Bloc<TodoListsEvents, TodoListsStates> {
  R _repository;
  ListCache<TodoList> cache;
  // Ensure that only one process modifies the cache and db at the same time
  // This is done to avoid problems with the db and the cache getting out of sync
  Mutex _writeMutex = Mutex();
  TodoListsBloc(repository): _repository=repository, super(TodoListsLoading());

  @override
  Stream<TodoListsStates> mapEventToState(TodoListsEvents event) async* {
    if (event is LoadTodoListsEvent) {
      yield* _mapLoadTodoListsEventToState(event);
    } else if (event is TodoListAddedEvent) {
      yield* _mapTodoListAddedEventToState(event);
    } else if (event is TodoListDeletedEvent) {
      yield* _mapTodoListDeletedEventToState(event);
    } else if (event is TodoListsReorderedEvent) {
      yield* _mapReorderTodoListsEventToState(event);
    }
  }

  Stream<TodoListsStates> _mapLoadTodoListsEventToState(LoadTodoListsEvent event) async* {
    await _writeMutex.acquire();
    var totalLength = await _repository.getNumberOfTodoLists();
    Future<List<TodoList>> underlyingData(int start, int end) {
      return _repository.getTodoListsChunk(start, end);
    }
    cache = ListCache(underlyingData, totalLength);
    await cache.init(0);
    yield TodoListsLoaded(cache);
    _writeMutex.release();
  }

  Stream<TodoListsStates> _mapTodoListAddedEventToState(TodoListAddedEvent event) async* {
    await _writeMutex.acquire();
    int id = await _repository.addTodoList(event.list);
    cache = cache.addElementAtEnd(event.list.withId(id));
    yield TodoListsLoaded(cache);
    _writeMutex.release();
  }

  Stream<TodoListsStates> _mapTodoListDeletedEventToState(TodoListDeletedEvent event) async* {
    await _writeMutex.acquire();
    cache = cache.removeElement(event.index, element: event.list);
    yield TodoListsLoaded(cache);
    await cancelRemindersForList(event.list, _repository);
    await _repository.deleteTodoList(event.list.id);
    _writeMutex.release();
  }

  Stream<TodoListsStates> _mapReorderTodoListsEventToState(TodoListsReorderedEvent event) async* {
    await _writeMutex.acquire();
    cache = cache.reorderElements(event.moveFromIndex, event.moveToIndex, event.moveFrom, elementTo: event.moveTo);
    yield TodoListsLoaded(cache);
    await _repository.moveTodoList(event.moveFrom.id, event.moveToIndex+1);
    _writeMutex.release();
  }
}