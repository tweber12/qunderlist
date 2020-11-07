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

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qunderlist/blocs/base.dart';
import 'package:qunderlist/notification_ffi.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';

import 'blocs/repeated.dart';

const int PENDING_ITEM_CREATE_PREFIX = 1<<30;
const int PENDING_ITEM_NOTIFICATION_PREFIX = 1<<31;

typedef FfiInit = NotificationFFI Function({@required String channelName, Function(int) notificationCallback, Function(int) completeItemCallback, Function() restoreAlarmsCallback, Function(int) createNextCallback});

class NotificationHandler {
  final bool foreground;
  final TodoRepository repository;
  BaseBloc _bloc; // ignore: close_sinks
  NotificationFFI _notificationFFI;

  NotificationHandler.foreground(TodoRepository repository):
        this.repository = repository,
        this.foreground = true;

  NotificationHandler.background(TodoRepository repository):
      this.repository = repository,
      this.foreground = false;

  Future<void> init(BaseBloc bloc, {FfiInit initializer = notificationFFIInitialize}) {
    if (foreground) {
      _bloc = bloc;
      _notificationFFI = initializer(
          channelName: NOTIFICATION_FFI_CHANNEL_NAME,
          notificationCallback: _notificationCallback,
          completeItemCallback: _completeItemCallback,
          restoreAlarmsCallback: _restoreAlarmsCallback,
          createNextCallback: _createNext
      );
      var handle = PluginUtilities.getCallbackHandle(_backgroundCallback).toRawHandle();
      return _notificationFFI.init(handle);
    } else {
      _notificationFFI = initializer(
          channelName: NOTIFICATION_FFI_BG_CHANNEL_NAME,
          notificationCallback: (_) {},
          completeItemCallback: _completeItemCallback,
          restoreAlarmsCallback: _restoreAlarmsCallback
      );
      return _notificationFFI.ready();
    }
  }

  Future<void> _notificationCallback(int itemId) async {
    var list = (await repository.getListsOfItem(itemId)).first;
    _bloc.add(BaseShowItemEvent(itemId, listId: list.id, list: list));
  }

  Future<void> _completeItemCallback(int itemId) async {
    var item = await repository.getTodoItem(itemId);
    if (item.completed) {
      return;
    }
    await cancelRemindersForItem(item);
    var newItem = item.toggleCompleted();
    await repository.updateTodoItem(newItem);
    await repository.triggerUpdate();
  }

  Future<void> _restoreAlarmsCallback() async {
    var reminders = await repository.getActiveReminders();
    for (final r in reminders) {
      var itemId = await repository.getItemOfReminder(r.id);
      var item = await repository.getTodoItem(itemId);
      if (item.completed) {
        continue;
      }
      await _notificationFFI.setReminder(item, r);
    }
  }

  Future<void> _createNext(int itemId) async {
    var item = await repository.getTodoItem(itemId);
    if (item.repeated.autoComplete) {
      if (item.repeated.keepHistory) {
        await repository.updateTodoItem(item.toggleCompleted());
      } else {
        await repository.deleteTodoItem(item.id);
      }
    } else {
      await repository.updateTodoItem(item.copyWith(repeated: Nullable(item.repeated.copyWith(active: false))));
    }
    var next = await repository.addTodoItem(nextItem(item));
    repository.triggerUpdate();
    await _replaceRemindersForPendingItem(item, next);
    await setPendingItem(next);
  }

  Future<void> setReminder(TodoItemBase item, Reminder reminder) {
    return _notificationFFI.setReminder(item, reminder);
  }

  Future<void> updateReminder(TodoItemBase item, Reminder reminder) {
    return _notificationFFI.updateReminder(item, reminder);
  }

  Future<void> cancelReminder(int reminderId) {
    return _notificationFFI.cancelReminder(reminderId);
  }

  Future<void> setRemindersForItem(TodoItemBase item) async {
    List<Reminder> reminders;
    if (item is TodoItem) {
      reminders = item.reminders;
    } else {
      reminders = await repository.getRemindersForItem(item.id);
    }
    for (final r in reminders) {
      await _notificationFFI.setReminder(item, r);
    }
  }

  Future<void> cancelRemindersForItem(TodoItemBase item) async {
    List<Reminder> reminders;
    if (item is TodoItem) {
      reminders = item.reminders;
    } else {
      reminders = await repository.getRemindersForItem(item.id);
    }
    for (final r in reminders) {
      await _notificationFFI.cancelReminder(r.id);
    }
  }

  Future<void> cancelRemindersForList(TodoList list) async {
    var reminders = await repository.getActiveRemindersForList(list.id);
    for (final reminder in reminders) {
      await _notificationFFI.cancelReminder(reminder.id);
    }
  }

  Future<void> setPendingItem(TodoItem basis, {TodoItem next}) async {
    if (next == null) {
      if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance == false) {
        return;
      }
      next = nextItem(basis);
    }
    await _setRemindersForPendingItem(basis, next);
    await _notificationFFI.setPendingItemAlarm(alarmId(basis.id), basis.id, _dateForPendingItemCreation(basis, next));
  }

  Future<void> cancelPendingItem(TodoItem basis, {TodoItem next}) async {
    if (next == null) {
      if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance == false) {
        return;
      }
      next = nextItem(basis);
    }
    await _cancelRemindersForPendingItem(basis);
    await _notificationFFI.cancelPendingItemAlarm(alarmId(basis.id));
  }

  DateTime _dateForPendingItemCreation(TodoItem basis, TodoItem next) {
    var dayAfter = DateTime(basis.dueDate.year, basis.dueDate.month, basis.dueDate.day+1);
    if (next.reminders.isEmpty) {
      return dayAfter;
    }
    next.reminders.sort((a,b) => a.at.compareTo(b.at));
    var firstReminder = next.reminders.first.at;
    if (dayAfter.isBefore(firstReminder)) {
      return dayAfter;
    } else {
      return DateTime(firstReminder.year, firstReminder.month, firstReminder.day);
    }
  }

  Future<void> _setRemindersForPendingItem(TodoItem basis, TodoItem next) async {
    if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance != true) {
      return;
    }
    for (int i=0; i<basis.reminders.length; i++) {
      var oldReminder = basis.reminders[i];
      var newReminder = next.reminders[i];
      await _notificationFFI.setReminder(next, newReminder.withId(reminderId(oldReminder.id)));
    }
  }

  Future<void> _cancelRemindersForPendingItem(TodoItem basis) async {
    if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance != true) {
      return;
    }
    for (final r in basis.reminders) {
      await _notificationFFI.cancelReminder(reminderId(r.id));
    }
  }

  Future<void> _replaceRemindersForPendingItem(TodoItem basis, TodoItem next) async {
    if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance != true) {
      return;
    }
    for (int i=0; i<basis.reminders.length; i++) {
      var oldReminder = basis.reminders[i];
      var newReminder = next.reminders[i];
      if (newReminder.at.isBefore(DateTime.now())) {
        await _notificationFFI.updateReminder(next, newReminder.withId(reminderId(oldReminder.id)));
      } else {
        await _notificationFFI.cancelReminder(reminderId(oldReminder.id));
        await _notificationFFI.setReminder(next, newReminder);
      }
    }
  }
}

int alarmId(int itemId) {
  return itemId | PENDING_ITEM_CREATE_PREFIX;
}

int reminderId(int reminderId) {
  return reminderId | PENDING_ITEM_NOTIFICATION_PREFIX;
}

void _backgroundCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  var repository = await TodoRepositorySqflite.getInstance();
  var handler = NotificationHandler.background(repository);
  await handler.init(null);
}
