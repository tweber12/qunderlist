// Copyright 2020 Torsten Weber
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:mutex/mutex.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/blocs/repeated/repeated_bloc.dart';
import 'package:qunderlist/blocs/todo_list/todo_list_events.dart';
import 'package:qunderlist/blocs/todo_list/todo_list_states.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoListBloc<R extends TodoRepository> extends Bloc<TodoListEvent, TodoListStates> {
  R _repository;
  TodoListsBloc _listsBloc;
  TodoList _list;
  // Ensure that only one process modifies the cache and db at the same time
  // This is done to avoid problems with the db and the cache getting out of sync
  final Mutex _writeMutex = Mutex();
  StreamSubscription<ExternalUpdate> _updateStream;
  TodoListBloc(R repository, TodoList list, {TodoStatusFilter filter: TodoStatusFilter.active, TodoListsBloc listsBloc}):
        _repository=repository,
        _listsBloc=listsBloc,
        _list=list,
        this.filter=filter,
        super(TodoListLoading(list))
  {
    _updateStream = _repository.updateStream.listen((_) => add(NotifyItemUpdateEvent(null)));
  }

  ListCache<TodoItemShort> cache;
  TodoStatusFilter filter;
  TodoListOrdering ordering;

  int get listId => _list.id;
  Palette get color => _list.color;

  @override
  Stream<TodoListStates> mapEventToState(TodoListEvent event) async* {
    if (event is RenameListEvent) {
      yield* _mapRenameListEventToState(event);
    } else if (event is ChangeListColorEvent) {
      yield* _mapChangeListColorEventToState(event);
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
    await _writeMutex.acquire();
    _list = TodoList(event.name, _list.color, id: _list.id);
    yield TodoListLoaded(_list, cache);
    await _repository.updateTodoList(_list);
    _notifyListsBloc();
    _writeMutex.release();
  }
  Stream<TodoListStates> _mapChangeListColorEventToState(ChangeListColorEvent event) async* {
    await _writeMutex.acquire();
    _list = TodoList(_list.listName, event.color, id: _list.id);
    yield TodoListLoaded(_list, cache);
    await _repository.updateTodoList(_list);
    _notifyListsBloc();
    _writeMutex.release();
  }
  Stream<TodoListStates> _mapDeleteListEventToState(DeleteListEvent event) async* {
    await cancelRemindersForList(_list, _repository);
    await _repository.deleteTodoList(_list.id);
    yield TodoListDeleted();
    _notifyListsBloc();
  }
  Stream<TodoListStates> _mapGetDataEventToState(GetDataEvent event) async* {
    yield* _updateCacheWithFilter(event.filter);
  }
  Stream<TodoListStates> _mapNotifyItemUpdateEventToState(NotifyItemUpdateEvent event) async* {
    if (event.item != null) {
      _notifyListsBloc();
    }
    yield* _updateCacheForce();
  }
  Stream<TodoListStates> _mapAddItemEventToState(AddItemEvent event) async* {
    await _writeMutex.acquire();
    var item = await _repository.addTodoItem(event.item, onList: _list);
    cache = cache.addElementAtEnd(item.shorten());
    yield TodoListLoaded(_list, cache);
    setRemindersForItem(item, _repository);
    _notifyListsBloc();
    _writeMutex.release();
  }
  Stream<TodoListStates> _mapDeleteItemEventToState(DeleteItemEvent event) async* {
    await _writeMutex.acquire();
    cache = cache.removeElement(event.index, element: event.item);
    yield TodoListLoaded(_list, cache);
    var numberOfLists = (await _repository.getListsOfItem(event.item.id)).length;
    if (numberOfLists > 1) {
      // The item is still contained in other lists, so don't delete it
      await _repository.removeTodoItemFromList(event.item.id, _list.id);
    } else {
      // No other lists contain this item, so delete it and all it's reminders
      await _repository.deleteTodoItem(event.item.id);
      cancelRemindersForItem(event.item, _repository);
    }
    _notifyListsBloc();
    _writeMutex.release();
  }

  Stream<TodoListStates> _mapCompleteItemEventToState(CompleteItemEvent event) async* {
    await _writeMutex.acquire();
    var newItem = event.item.toggleCompleted();
    // There's not a single view which shows completed and uncompleted items, so remove it since it must've been visible before
    cache = cache.removeElement(event.index, element: event.item);
    yield TodoListLoaded(_list, cache);
    if (newItem.completed) {
      // The event has been completed, so remove all notifications
      cancelRemindersForItem(event.item, _repository);
    } else {
      // The event has been activated again, so activate all notifications as well
      setRemindersForItem(event.item, _repository);
    }
    if (newItem.completed && newItem.repeatedStatus == RepeatedStatus.active) {
      // The item is repeated
      var fullItem = await _repository.getTodoItem(newItem.id);
      var next = nextItem(fullItem);
      add(AddItemEvent(next));
      if (fullItem.repeated.keepHistory) {
        _repository.updateTodoItem(newItem);
      } else {
        _repository.deleteTodoItem(newItem.id);
      }
    } else {
      _repository.updateTodoItem(newItem);
    }
    _notifyListsBloc();
    _writeMutex.release();
  }

  Stream<TodoListStates> _mapUpdateItemPriorityEventToState(UpdateItemPriorityEvent event) async* {
    await _writeMutex.acquire();
    var newItem = event.item.copyWith(priority: event.priority);
    if (filter == TodoStatusFilter.important) {
      if (event.priority == TodoPriority.none) {
        // The item now fails the filter, so it has to be removed from the cache
        cache = cache.removeElement(event.index, element: event.item);
      } else {
        // The item has changed priority, but is still shown in the list
        // That means that it's location in the list has most likely changed
        // Instead of tracking that in the cache, reload the whole thing from the db
        await _repository.updateTodoItem(newItem);
        yield* _updateCacheForce();
        return;
      }
    } else {
      // In all other cases, the element is still being shown at the same location, so update it accordingly
      cache = cache.updateElement(event.index, element: newItem);
    }
    yield TodoListLoaded(_list, cache);
    await _repository.updateTodoItem(newItem);
    _writeMutex.release();
  }
  Stream<TodoListStates> _mapReorderItemsEventToState(ReorderItemsEvent event) async* {
    await _writeMutex.acquire();
    cache = cache.reorderElements(event.moveFromIndex, event.moveToIndex, event.moveFrom, elementTo: event.moveTo);
    yield TodoListLoaded(_list, cache);
    await _repository.moveTodoItemInList(event.moveFrom.id, _list.id, event.moveTo.id);
    _writeMutex.release();
  }
  Stream<TodoListStates> _mapUpdateFilterEventToState(UpdateFilterEvent event) async* {
    yield* _updateCacheWithFilter(event.filter);
  }
  Stream<TodoListStates> _updateCacheWithFilter(TodoStatusFilter filter) async* {
    if (cache != null && filter == this.filter) {
      yield TodoListLoaded(_list, cache);
      return;
    }
    yield* _updateCacheForce(newFilter: filter);
  }
  Stream<TodoListStates> _updateCacheForce({TodoStatusFilter newFilter}) async* {
    await _writeMutex.acquire();
    var filter = newFilter ?? this.filter;
    var totalLength = await _repository.getNumberOfTodoItems(_list.id, filter);
    Future<List<TodoItemShort>> underlyingData(int start, int end) {
      return _repository.getTodoItemsOfListChunk(_list.id, start, end, filter);
    }
    var newCache = ListCache(underlyingData, totalLength);
    await newCache.init(0);
    cache = newCache;
    this.filter = filter;
    yield TodoListLoaded(_list, cache);
    _writeMutex.release();
  }

  void _notifyListsBloc() {
    _listsBloc?.add(ExternalUpdateEvent());
  }

  @override
  Future<void> close() {
    _updateStream.cancel();
    return super.close();
  }
}