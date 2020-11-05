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
import 'package:qunderlist/blocs/repeated.dart';
import 'package:qunderlist/blocs/todo_details/todo_details_events.dart';
import 'package:qunderlist/blocs/todo_details/todo_details_states.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/notification_ffi.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/repository/repository.dart';

class RateLimit {
  final Duration _gap;
  final Function() _callback;

  bool _timeout = false;
  bool _requestDuringTimeout = false;

  RateLimit(this._gap, this._callback);

  void call() async {
    if (_timeout) {
      _requestDuringTimeout = true;
      return;
    }
    _timeout = true;
    _requestDuringTimeout = false;
    _callback();
    await Future.delayed(_gap);
    _timeout = false;
    if (_requestDuringTimeout) {
      call();
    }
  }
}

class TodoDetailsBloc<R extends TodoRepository> extends Bloc<TodoDetailsEvent,TodoDetailsState> {
  int _itemId;
  TodoItemBase _baseItem;
  TodoItem _fullItem;
  final TodoListBloc _listBloc;
  final R _repository;
  final NotificationHandler _notificationHandler;
  RateLimit notifier;
  // Ensure that only one process modifies the cache and db at the same time
  // This is done to avoid problems with the db and the cache getting out of sync
  final Mutex _writeMutex = Mutex();
  StreamSubscription _updateStream;

  TodoDetailsBloc(R repository, NotificationHandler notificationHandler, int itemId, {TodoItemBase item, TodoListBloc listBloc}):
        _repository=repository,
        _notificationHandler=notificationHandler,
        _listBloc=listBloc,
        _baseItem=item,
        _itemId = itemId,
        super(item==null ? TodoDetailsLoading() : item is TodoItem ? TodoDetailsFullyLoaded(item, listBloc.color) : TodoDetailsLoadedShortItem(item, listBloc.color))
  {
    notifier = _listBloc!=null ? RateLimit(Duration(seconds: 1), _notifyHelper) : null;
    _updateStream = _repository.updateStream.listen((_) => add(ExternalUpdateEvent()));
    if (_baseItem is TodoItem) {
      _fullItem = _baseItem;
    }
  }

  int get itemId => _itemId;

  @override
  Stream<TodoDetailsState> mapEventToState(TodoDetailsEvent event) async* {
    if (event is LoadItemEvent) {
      yield* _mapLoadItemEventToState(event);
    } else if (event is UpdateTitleEvent) {
      yield* _mapUpdateTitleEventToState(event);
    } else if (event is ToggleCompletedEvent) {
      yield* _mapToggleCompletedEventToState(event);
    } else if (event is UpdatePriorityEvent) {
      yield* _mapUpdatePriorityEventToState(event);
    } else if (event is UpdateNoteEvent) {
      yield* _mapUpdateNoteEventToState(event);
    } else if (event is UpdateDueDateEvent) {
      yield* _mapUpdateDueDateEventToState(event);
    } else if (event is UpdateRepeatedEvent) {
      yield* _mapUpdateRepeatedEventToState(event);
    } else if (event is AddReminderEvent) {
      yield* _mapAddReminderEventToState(event);
    } else if (event is UpdateReminderEvent) {
      yield* _mapUpdateReminderEventToState(event);
    } else if (event is DeleteReminderEvent) {
      yield* _mapDeleteReminderEventToState(event);
    } else if (event is AddToListEvent) {
      yield* _mapAddToListEventToState(event);
    } else if (event is RemoveFromListEvent) {
      yield* _mapRemoveFromListEventToState(event);
    } else if (event is MoveToListEvent) {
      yield* _mapMoveToListEventToState(event);
    } else if (event is CopyToListEvent) {
      yield* _mapCopyToListEventToState(event);
    } else if (event is DeleteEvent) {
      yield* _mapDeleteEventToState(event);
    } else if (event is ExternalUpdateEvent) {
      yield* _externalUpdate(event);
    } else {
      throw "BUG: Unhandled TodoDetailsEvent!";
    }
  }

  Stream<TodoDetailsState> _mapLoadItemEventToState(LoadItemEvent event) async* {
    if (_fullItem == null) {
      if (_baseItem != null) {
        yield TodoDetailsLoadedShortItem(_baseItem, _listBloc.color);
      }
      _fullItem = await _repository.getTodoItem(_itemId);
    }
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
  }

  Stream<TodoDetailsState> _mapUpdateTitleEventToState(UpdateTitleEvent event) async* {
    await _writeMutex.acquire();
    _fullItem = _fullItem.copyWith(todo: event.newTitle);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.updateTodoItem(_fullItem);
    updateReminders(_fullItem);
    _notificationHandler.setPendingItem(_fullItem);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdatePriorityEventToState(UpdatePriorityEvent event) async* {
    await _writeMutex.acquire();
    _fullItem = _fullItem.copyWith(priority: event.newPriority);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.updateTodoItem(_fullItem);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapToggleCompletedEventToState(ToggleCompletedEvent event) async* {
    await _writeMutex.acquire();
    _fullItem = _fullItem.toggleCompleted();
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    if (_fullItem.completed) {
      _notificationHandler.cancelRemindersForItem(_fullItem);
      if (_fullItem.repeatedStatus == RepeatedStatus.active) {
        _notificationHandler.cancelPendingItem(_fullItem);
        var next = await _repository.addTodoItem(nextItem(_fullItem));
        _notificationHandler.setRemindersForItem(next);
      }
    } else {
      _notificationHandler.setRemindersForItem(_fullItem);
      _notificationHandler.setPendingItem(_fullItem);
    }
    if (_fullItem.completed && !(_fullItem.repeated?.keepHistory ?? true)) {
      await _repository.deleteTodoItem(_fullItem.id);
    } else {
      await _repository.updateTodoItem(_fullItem);
    }
    _notifyList();
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdateNoteEventToState(UpdateNoteEvent event) async* {
    await _writeMutex.acquire();
    _fullItem = _fullItem.copyWith(note: Nullable(event.newNote));
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.updateTodoItem(_fullItem);
    updateReminders(_fullItem);
    _notificationHandler.setPendingItem(_fullItem);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdateDueDateEventToState(UpdateDueDateEvent event) async* {
    await _writeMutex.acquire();
    if (event.newDueDate == null) {
      _notificationHandler.cancelPendingItem(_fullItem);
      _fullItem = _fullItem.copyWith(dueDate: Nullable(event.newDueDate), repeated: Nullable(null));
    } else {
      _fullItem = _fullItem.copyWith(dueDate: Nullable(event.newDueDate), repeated: Nullable(_fullItem.repeated?.copyWith(active: true)));
      _notificationHandler.setPendingItem(_fullItem);
    }
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.updateTodoItem(_fullItem);
    await _repository.updateRepeated(_fullItem.id, _fullItem.repeated);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdateRepeatedEventToState(UpdateRepeatedEvent event) async* {
    await _writeMutex.acquire();
    var dueDate;
    if (event.repeated != null && _fullItem.dueDate == null) {
      var now = DateTime.now();
      dueDate = DateTime(now.year, now.month, now.day);
      _fullItem = _fullItem.copyWith(dueDate: Nullable(dueDate), repeated: Nullable(event.repeated));
    } else {
      _fullItem = _fullItem.copyWith(repeated: Nullable(event.repeated));
    }
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    if (dueDate != null) {
      await _repository.updateTodoItem(_fullItem);
    }
    await _repository.updateRepeated(_fullItem.id, _fullItem.repeated);
    if (event.repeated != null && event.repeated.autoAdvance) {
      _notificationHandler.setPendingItem(_fullItem);
    } else {
      _notificationHandler.cancelPendingItem(_fullItem);
    }
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapAddReminderEventToState(AddReminderEvent event) async* {
    await _writeMutex.acquire();
    var id = await _repository.addReminder(_fullItem.id, event.reminder.at);
    var newReminders = List.of(_fullItem.reminders);
    newReminders.add(event.reminder.withId(id));
    _fullItem = _fullItem.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    _notificationHandler.setReminder(_fullItem, event.reminder.withId(id));
    _notificationHandler.setPendingItem(_fullItem);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdateReminderEventToState(UpdateReminderEvent event) async* {
    await _writeMutex.acquire();
    var newReminders = _fullItem.reminders.map((r) {return r.id == event.reminder.id ? event.reminder : r;}).toList();
    _fullItem = _fullItem.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.updateReminder(event.reminder.id, event.reminder.at);
    _notificationHandler.updateReminder(_fullItem, event.reminder);
    _notificationHandler.setPendingItem(_fullItem);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapDeleteReminderEventToState(DeleteReminderEvent event) async* {
    await _writeMutex.acquire();
    var newReminders = _fullItem.reminders.where((element) => element.id != event.reminder.id).toList();
    _fullItem = _fullItem.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.deleteReminder(event.reminder.id);
    _notificationHandler.cancelReminder(event.reminder.id);
    _notificationHandler.setPendingItem(_fullItem);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapAddToListEventToState(AddToListEvent event) async* {
    await _writeMutex.acquire();
    var lists = [_fullItem.onLists, event.list];
    _fullItem = _fullItem.copyWith(onLists: lists);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.addTodoItemToList(_fullItem.id, event.list.id);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapRemoveFromListEventToState(RemoveFromListEvent event) async* {
    await _writeMutex.acquire();
    var lists = _fullItem.onLists.where((element) => element.id != event.listId).toList();
    _fullItem = _fullItem.copyWith(onLists: lists);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.removeTodoItemFromList(_fullItem.id, event.listId);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapMoveToListEventToState(MoveToListEvent event) async* {
    await _writeMutex.acquire();
    var lists = [event.newList, ..._fullItem.onLists.where((element) => element.id != event.oldListId)];
    _fullItem = _fullItem.copyWith(onLists: lists);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    await _repository.moveTodoItemToList(_fullItem.id, event.oldListId, event.newList.id);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapCopyToListEventToState(CopyToListEvent event) async* {
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
    _notifyList();
    _repository.addTodoItem(_fullItem, onList: event.list);
  }

  Stream<TodoDetailsState> _mapDeleteEventToState(DeleteEvent event) async* {
    _notifyList();
    await _repository.deleteTodoItem(_fullItem.id);
    _notificationHandler.cancelRemindersForItem(_fullItem);
    _notificationHandler.cancelPendingItem(_fullItem);
  }

  Stream<TodoDetailsState> _externalUpdate(ExternalUpdateEvent event) async* {
    _fullItem = await _repository.getTodoItem(_itemId);
    yield TodoDetailsFullyLoaded(_fullItem, _listBloc.color);
  }

  Future<void> _notifyList() async {
    notifier?.call();
  }

  void _notifyHelper() {
    if (_fullItem != null) {
      _listBloc.add(NotifyItemUpdateEvent(_fullItem.shorten()));
    }
  }

  Future<void> updateReminders(TodoItem item) async {
    for (final r in item.reminders) {
      await _notificationHandler.updateReminder(item, r);
    }
  }

  @override
  Future<void> close() {
    _updateStream.cancel();
    _notifyHelper();
    return super.close();
  }
}