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
  StreamSubscription<ExternalUpdate> _updateStream;
  TodoListsBloc(repository): _repository=repository, super(TodoListsLoading()) {
    _updateStream = repository.updateStream.listen((_) => add(ExternalUpdateEvent()));
  }

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
    } else if (event is ExternalUpdateEvent) {
      yield* _externalUpdate(event);
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

  Stream<TodoListsStates> _externalUpdate(ExternalUpdateEvent event) async* {
    await _writeMutex.acquire();
    var totalLength = await _repository.getNumberOfTodoLists();
    Future<List<TodoList>> underlyingData(int start, int end) {
      return _repository.getTodoListsChunk(start, end);
    }
    var newCache = ListCache(underlyingData, totalLength);
    await newCache.init(0);
    cache = newCache;
    yield TodoListsLoaded(cache);
    _writeMutex.release();
  }

  @override
  Future<void> close() {
    _updateStream.cancel();
    return super.close();
  }
}