import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/blocs/todo_list/todo_list_events.dart';
import 'package:qunderlist/blocs/todo_list/todo_list_states.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoListBloc<R extends TodoRepository> extends Bloc<TodoListEvent, TodoListStates> {
  R _repository;
  TodoList _list;
  TodoListBloc(R repository, TodoList list): _repository=repository, _list=list, super(TodoListLoading(list));

  ListCache<TodoItem> cache;
  TodoStatusFilter filter;
  TodoListOrdering ordering;

  int get listId => _list.id;

  @override
  Stream<TodoListStates> mapEventToState(TodoListEvent event) async* {
    if (event is RenameListEvent) {
      yield* _mapRenameListEventToState(event);
    } else if (event is DeleteListEvent) {
      yield* _mapDeleteListEventToState(event);
    } else if (event is GetDataEvent) {
      yield* _mapGetDataEventToState(event);
    } else if (event is NotifyItemUpdateEvent) {
      yield* _mapNotifyItemUpdateEventToState(event);
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
    yield TodoListLoaded(_list, cache);
  }
  Stream<TodoListStates> _mapDeleteListEventToState(DeleteListEvent event) async* {
    await cancelAllNotificationsForList(_list, _repository);
    await _repository.deleteTodoList(_list);
    yield TodoListDeleted();
  }
  Stream<TodoListStates> _mapGetDataEventToState(GetDataEvent event) async* {
    yield* _updateCache(event.filter, event.ordering);
  }
  Stream<TodoListStates> _mapNotifyItemUpdateEventToState(NotifyItemUpdateEvent event) async* {
    if (event.index < cache.chainStart || event.index > cache.chainEnd) {
      // There is a corner case where the element was at the last position and removed
      // In that case the element index is not contained in the cached range anymore
      // That is what the slightly extended range is for
      return;
    }
    bool shouldNotBeContained = !event.lists.contains(_list)
      || (filter==TodoStatusFilter.active && event.item.completed)
      || (filter==TodoStatusFilter.completed && !event.item.completed)
      || (filter==TodoStatusFilter.important && event.item.priority!=TodoPriority.high)
      || (filter==TodoStatusFilter.withDueDate && event.item.dueDate==null);
    if (event.index == cache.chainEnd) {
      // Handle the corner case of the event being exactly at the end of the chain
      if (!shouldNotBeContained) {
        // If the event should be there and fits exactly at the end of the chain, then add it
        cache = cache.addElement(event.index, event.item);
        yield TodoListLoaded(_list, cache);
      }
      // In any case return, so that all events in the remainder of the code fit in the cached range
      return;
    }
    print("NOTIFY ITEM UPDATE: ${cache[event.index].id == event.item.id}, $shouldNotBeContained");
    if (cache[event.index].id == event.item.id && shouldNotBeContained) {
      print("REMOVING ELEMENT");
      cache = cache.removeElement(event.index);
    } else if (cache[event.index].id != event.item.id && !shouldNotBeContained) {
      print("ADDING IT AGAIN");
      cache = cache.addElement(event.index, event.item);
    } else {
      cache = cache.updateElement(event.index, event.item);
    }
    yield TodoListLoaded(_list, cache);
  }
  Stream<TodoListStates> _mapAddItemEventToState(AddItemEvent event) async* {
    var id = await _repository.addTodoItem(event.item, _list.id);
    cache = cache.addElement(cache.totalNumberOfItems, event.item.copyWith(id: id));
    yield TodoListLoaded(_list, cache);
    setAllNotificationsForItem(event.item);
  }
  Stream<TodoListStates> _mapDeleteItemEventToState(DeleteItemEvent event) async* {
    cache = cache.removeElement(event.index);
    yield TodoListLoaded(_list, cache);
    await _repository.removeTodoItemFromList(event.item, _list.id);
    cancelAllNotificationsForItem(event.item);
  }
  Stream<TodoListStates> _mapCompleteItemEventToState(CompleteItemEvent event) async* {
    var newItem = event.item.toggleCompleted();
    if (filter == TodoStatusFilter.active || filter == TodoStatusFilter.completed) {
      // In these two cases, the item won't be included in the list anymore
      cache = cache.removeElement(event.index);
      cancelAllNotificationsForItem(event.item);
    } else {
      cache = cache.updateElement(event.index, newItem);
      setAllNotificationsForItem(event.item);
    }
    yield TodoListLoaded(_list, cache);
    await _repository.updateTodoItem(newItem);
  }
  Stream<TodoListStates> _mapUpdateItemPriorityEventToState(UpdateItemPriorityEvent event) async* {
    var newItem = event.item.copyWith(priority: event.priority);
    if (filter == TodoStatusFilter.important) {
      // The item now fails the filter, so it has to be removed from the cache
      cache = cache.removeElement(event.index);
    } else {
      // In all other cases, the element is still being shown, so update it accordingly
      cache = cache.updateElement(event.index, newItem);
    }
    yield TodoListLoaded(_list, cache);
    await _repository.updateTodoItem(newItem);
  }
  Stream<TodoListStates> _mapReorderItemsEventToState(ReorderItemsEvent event) async* {
    var item = await cache.peekItem(event.moveFrom);
    var oldCache = cache;
    var newCache = cache.removeElement(event.moveFrom);
//    int moveTo = event.moveTo > event.moveFrom ? event.moveTo-1 : event.moveTo;
    newCache = newCache.addElement(event.moveTo, item);
    cache = newCache;
    yield TodoListLoaded(_list, cache);
    var moveToItem = await oldCache.peekItem(event.moveTo);
    await _repository.moveItemInList(item, _list.id, moveToItem.id);
  }
  Stream<TodoListStates> _mapUpdateFilterEventToState(UpdateFilterEvent event) async* {
    yield* _updateCache(event.filter, ordering);
  }
  Stream<TodoListStates> _updateCache(TodoStatusFilter filter, TodoListOrdering ordering) async* {
    if (cache != null && filter == this.filter && ordering == this.ordering) {
      yield TodoListLoaded(_list, cache);
      return;
    }
    this.filter = filter;
    this.ordering = ordering;
    var totalLength = await _repository.getNumberOfItems(_list.id, filter: filter);
    Future<List<TodoItem>> underlyingData(int start, int end) {
      return _repository.getTodoItemsOfListChunk(_list.id, start, end, filter: filter);
    }
    cache = ListCache(underlyingData, totalLength);
    await cache.init(0);
    yield TodoListLoaded(_list, cache);
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