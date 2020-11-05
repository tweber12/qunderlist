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

typedef FfiInit = NotificationFFI Function({@required String channelName, Function(int) notificationCallback, Function(int) completeItemCallback, Function() restoreAlarmsCallback});

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
          restoreAlarmsCallback: _restoreAlarmsCallback
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
    await cancelRemindersForItem(item, repository);
    var newItem = item.toggleCompleted();
    await repository.updateTodoItem(newItem);
    repository.triggerUpdate();
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

  Future<void> setReminder(TodoItemBase item, Reminder reminder) {
    return _notificationFFI.setReminder(item, reminder);
  }

  Future<void> updateReminder(TodoItemBase item, Reminder reminder) {
    return _notificationFFI.updateReminder(item, reminder);
  }

  Future<void> cancelReminder(int reminderId) {
    return _notificationFFI.cancelReminder(reminderId);
  }

  Future<void> setRemindersForItem<R extends TodoRepository>(TodoItemBase item, R repository) async {
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

  Future<void> cancelRemindersForItem<R extends TodoRepository>(TodoItemBase item, R repository) async {
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

  Future<void> cancelRemindersForList<R extends TodoRepository>(TodoList list, R repository) async {
    var reminders = await repository.getActiveRemindersForList(list.id);
    for (final reminder in reminders) {
      await _notificationFFI.cancelReminder(reminder.id);
    }
  }
}

void _backgroundCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  var repository = await TodoRepositorySqflite.getInstance();
  var handler = NotificationHandler.background(repository);
  await handler.init(null);
}