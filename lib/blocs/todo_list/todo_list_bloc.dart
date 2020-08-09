import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:qunderlist/blocs/todo_list/todo_list_events.dart';
import 'package:qunderlist/blocs/todo_list/todo_list_states.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoListBloc<R extends TodoRepository> extends Bloc<TodoListEvent, TodoListStates> {
  R _repository;
  TodoList _list;
  TodoListBloc(R repository, TodoList list): _repository=repository, _list=list, super(TodoListLoading(list));

  int start;
  int end;
  Chunk<TodoItem> lastChunk;
  TodoStatusFilter filter;
  TodoListOrdering ordering;

  @override
  Stream<TodoListStates> mapEventToState(TodoListEvent event) async* {
    if (event is RenameListEvent) {
      yield* _mapRenameListEventToState(event);
    } else if (event is DeleteListEvent) {
      yield* _mapDeleteListEventToState(event);
    } else if (event is GetDataEvent) {
      yield* _mapGetDataEventToState(event);
    } else if (event is ReloadDataEvent) {
      yield* _mapReloadDataEventToState(event);
    } else if (event is AddItemEvent) {
      yield* _mapAddItemEventToState(event);
    } else if (event is DeleteItemEvent) {
      yield* _mapDeleteItemEventToState(event);
    } else if (event is CompleteItemEvent) {
      yield* _mapCompleteItemEventToState(event);
    } else if (event is ReorderItemsEvent) {
      yield* _mapReorderItemsEventToState(event);
    } else if (event is UpdateItemPriorityEvent) {
      yield* _mapUpdateItemPriorityEventToState(event);
    } else if (event is UpdateFilterEvent) {
      yield* _mapUpdateFilterEventToState(event);
    } else {
      throw "BUG: Unhandled event in TodoListBloc ($event)!";
    }
  }

  Stream<TodoListStates> _mapRenameListEventToState(RenameListEvent event) async* {
    await _repository.updateTodoList(TodoList(event.name, id: _list.id));
    yield TodoListLoaded(_list, lastChunk);
  }
  Stream<TodoListStates> _mapDeleteListEventToState(DeleteListEvent event) async* {
    await _repository.deleteTodoList(_list);
    yield TodoListDeleted();
  }
  Stream<TodoListStates> _mapGetDataEventToState(GetDataEvent event) async* {
    if (lastChunk != null) {
      ChunkRange range = event.fromBottom ? ChunkRange.fromBottom(event.start, event.end, lastChunk.totalLength) : ChunkRange(event.start, event.end);
      var oldRange = ChunkRange(lastChunk.start, lastChunk.end);
      if (event.filter == filter && event.ordering == ordering && oldRange.contains(range)) {
        yield TodoListLoaded(_list, lastChunk);
        return;
      }
      range = range.union(oldRange);
    }
    // TODO Only load new pieces, if possible
    var totalLength = await _repository.getNumberOfItems(_list.id, filter: event.filter);
    ChunkRange range = event.fromBottom ? ChunkRange.fromBottom(event.start, event.end, totalLength) : ChunkRange(event.start, event.end);
    var list = await _repository.getTodoItemsOfListChunk(_list.id, range._start, range._end, filter: event.filter);
    var chunk = Chunk(range._start, list, totalLength);
    start = range._start;
    end = range._end;
    lastChunk = chunk;
    filter = event.filter;
    ordering = event.ordering;
    yield TodoListLoaded(_list, chunk);
  }
  Stream<TodoListStates> _mapReloadDataEventToState(ReloadDataEvent event) async* {
    yield* _reloadChunk();
  }
  Stream<TodoListStates> _mapAddItemEventToState(AddItemEvent event) async* {
    await _repository.addTodoItem(event.item, _list.id);
    yield* _reloadChunk();
  }
  Stream<TodoListStates> _mapDeleteItemEventToState(DeleteItemEvent event) async* {
    await _repository.removeTodoItemFromList(event.item, _list.id);
    yield* _reloadChunk();
  }
  Stream<TodoListStates> _mapCompleteItemEventToState(CompleteItemEvent event) async* {
    await _repository.completeTodoItem(event.item);
    yield* _reloadChunk();
  }
  Stream<TodoListStates> _mapUpdateItemPriorityEventToState(UpdateItemPriorityEvent event) async* {
    var newItem = event.item.copyWith(priority: event.priority);
    await _repository.updateTodoItem(newItem);
    if (filter != TodoStatusFilter.important && _lastChunkHasItem(newItem, event.index)) {
      var list = lastChunk.data.map((e) => e.id==newItem.id ? newItem : e).toList();
      lastChunk = Chunk(lastChunk.start, list, lastChunk.totalLength);
      yield TodoListLoaded(_list, lastChunk);
    } else {
      yield* _reloadChunk();
    }
  }
  Stream<TodoListStates> _mapReorderItemsEventToState(ReorderItemsEvent event) async* {
    await _repository.moveItemInList(event.item, _list.id, event.moveTo);
    yield* _reloadChunk();
  }
  Stream<TodoListStates> _mapUpdateFilterEventToState(UpdateFilterEvent event) async* {
    filter = event.filter;
    yield* _reloadChunk();
  }

  Stream<TodoListStates> _reloadChunk() async* {
    var totalLength = await _repository.getNumberOfItems(_list.id, filter: filter);
    var list = await _repository.getTodoItemsOfListChunk(_list.id, start, end, filter: filter);
    var chunk = Chunk(lastChunk.start, list, totalLength);
    lastChunk = chunk;
    yield TodoListLoaded(_list, lastChunk);
  }

  bool _lastChunkHasItem(TodoItem item, int index) {
    if (lastChunk == null) {
      return false;
    }
    if (index == null) {
      for (final i in lastChunk.data) {
        if (i.id == item.id) {
          return true;
        }
      }
      return false;
    } else {
      return lastChunk.contains(index);
    }
  }
}

class ChunkRange {
  final int _start;
  final int _end;
  ChunkRange(int start, int end): _start = start>=0 ? start : 0, _end = end;
  ChunkRange.fromBottom(int start, int end, int length): _start = (length-start)>=0 ? length-start : 0, _end = length-end;

  bool contains(ChunkRange other) {
    return _start >= other._start && _end <= other._end;
  }

  ChunkRange union(ChunkRange other) {
    return ChunkRange(min(_start, other._start), max(_end, other._end));
  }
}