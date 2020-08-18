import 'package:bloc/bloc.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/blocs/todo_lists/todo_lists_events.dart';
import 'package:qunderlist/blocs/todo_lists/todo_lists_states.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoListsBloc<R extends TodoRepository> extends Bloc<TodoListsEvents, TodoListsStates> {
  R _repository;
  ListCache<TodoList> cache;
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
    var totalLength = await _repository.getNumberOfTodoLists();
    Future<List<TodoList>> underlyingData(int start, int end) {
      return _repository.getTodoListsChunk(start, end);
    }
    cache = ListCache(underlyingData, totalLength);
    await cache.init(0);
    yield TodoListsLoaded(cache);
  }

  Stream<TodoListsStates> _mapTodoListAddedEventToState(TodoListAddedEvent event) async* {
    int id = await _repository.addTodoList(event.list);
    cache = cache.addElement(cache.totalNumberOfItems, event.list.withId(id));
    yield TodoListsLoaded(cache);
  }

  Stream<TodoListsStates> _mapTodoListDeletedEventToState(TodoListDeletedEvent event) async* {
    cache = cache.removeElement(event.index);
    yield TodoListsLoaded(cache);
    await _repository.deleteTodoList(event.list);
  }

  Stream<TodoListsStates> _mapReorderTodoListsEventToState(TodoListsReorderedEvent event) async* {
    var list = await cache.peekItem(event.moveFrom);
    var newCache = cache.removeElement(event.moveFrom);
    newCache = newCache.addElement(event.moveTo, list);
    cache = newCache;
    yield TodoListsLoaded(cache);
    await _repository.moveList(list, event.moveTo+1);
  }
}