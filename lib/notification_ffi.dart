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
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:qunderlist/screens/todo_item_screen.dart';
import 'package:qunderlist/screens/todo_list_screen.dart';

const String NOTIFICATION_FFI_CHANNEL_NAME = "com.torweb.qunderlist.notification_ffi_channel";
const String NOTIFICATION_FFI_BG_CHANNEL_NAME = "com.torweb.qunderlist.notification_ffi_background_channel";

const String NOTIFICATION_FFI_NOTIFICATION_CALLBACK = "notification_callback";
const String NOTIFICATION_FFI_COMPLETE_ITEM = "complete_item";
const String NOTIFICATION_FFI_RESTORE_ALARMS = "restore_alarms";


const String NOTIFICATION_FFI_SET_REMINDER = "set_reminder";
const String NOTIFICATION_FFI_UPDATE_REMINDER = "update_reminder";
const String NOTIFICATION_FFI_DELETE_REMINDER = "delete_reminder";
const String NOTIFICATION_FFI_INIT = "init";
const String NOTIFICATION_FFI_READY = "ready";

const String NOTIFICATION_FFI_ITEM_ID = "item_id";
const String NOTIFICATION_FFI_ITEM_TITLE = "title";
const String NOTIFICATION_FFI_ITEM_NOTE = "note";
const String NOTIFICATION_FFI_REMINDER_ID = "id";
const String NOTIFICATION_FFI_REMINDER_TIME = "at";

class NotificationFFI {
  static const MethodChannel METHOD_CHANNEL = const MethodChannel(NOTIFICATION_FFI_CHANNEL_NAME);
  static const MethodChannel METHOD_CHANNEL_BG = const MethodChannel(NOTIFICATION_FFI_BG_CHANNEL_NAME);

  static NotificationFFI _notificationFFI;

  factory NotificationFFI() {
    if (_notificationFFI == null) {
      _notificationFFI = NotificationFFI._internal();
    }
    return _notificationFFI;
  }

  NotificationFFI._internal(): _init = false;

  BuildContext _context;
  bool _init;

  Future<void> init(BuildContext context) async {
    if (_init) {
      return;
    }
    _init = true;
    _context = context;
    _setMethodCallHandler();
    var handle = PluginUtilities.getCallbackHandle(_backgroundCallback).toRawHandle();
    await _invoke(NOTIFICATION_FFI_INIT, handle);
    return ready();
  }

  Future<void> ready() {
    return _invoke(NOTIFICATION_FFI_READY);
  }

  static Future<void> setReminder(TodoItemBase item, Reminder reminder) {
    var args = {
      NOTIFICATION_FFI_REMINDER_ID: reminder.id,
      NOTIFICATION_FFI_REMINDER_TIME: reminder.at.millisecondsSinceEpoch,
      NOTIFICATION_FFI_ITEM_ID: item.id,
      NOTIFICATION_FFI_ITEM_TITLE: item.todo,
      NOTIFICATION_FFI_ITEM_NOTE: item.note
    };
    return _invoke(NOTIFICATION_FFI_SET_REMINDER, args);
  }

  static Future<void> updateReminder(TodoItemBase item, Reminder reminder) {
    var args = {
      NOTIFICATION_FFI_REMINDER_ID: reminder.id,
      NOTIFICATION_FFI_REMINDER_TIME: reminder.at.millisecondsSinceEpoch,
      NOTIFICATION_FFI_ITEM_ID: item.id,
      NOTIFICATION_FFI_ITEM_TITLE: item.todo,
      NOTIFICATION_FFI_ITEM_NOTE: item.note
    };
    return _invoke(NOTIFICATION_FFI_UPDATE_REMINDER, args);
  }

  static Future<void> cancelReminder(int reminderId) {
    return _invoke(NOTIFICATION_FFI_DELETE_REMINDER, reminderId);
  }

  static Future<dynamic> _invoke(String method, [dynamic arguments]) async {
    var result;
    try {
      result = await METHOD_CHANNEL.invokeMethod(method, arguments);
    } catch (err) {
      try {
        result = await METHOD_CHANNEL_BG.invokeMethod(method, arguments);
      } catch (err) {
        result = null;
      }
    }
    return result;
  }

  void _setMethodCallHandler() {
    METHOD_CHANNEL.setMethodCallHandler((call) async {
      switch (call.method) {
        case NOTIFICATION_FFI_NOTIFICATION_CALLBACK:
          var id = call.arguments as int;
          _notificationCallback(id);
          break;
        case NOTIFICATION_FFI_COMPLETE_ITEM:
          _completeItem(RepositoryProvider.of<TodoRepository>(_context), call.arguments as int);
          break;
        case NOTIFICATION_FFI_RESTORE_ALARMS:
          _restoreAlarms(RepositoryProvider.of<TodoRepository>(_context));
          break;
      }
    });
  }

  Future<void> _notificationCallback(int itemId) async {
    var repository = RepositoryProvider.of<TodoRepository>(_context);
    var list = (await repository.getListsOfItem(itemId)).first;
    var bloc = TodoListBloc(repository, list, filter: TodoStatusFilter.active, listsBloc: BlocProvider.of<TodoListsBloc>(_context));
    bloc.add(GetDataEvent(filter: TodoStatusFilter.active));
    var navigator = Navigator.of(_context);
    navigator.pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) =>
                showTodoListScreenExternal(context, bloc)
        ),
            (route) => route.settings.name == "/"
    );
    navigator.push(
      MaterialPageRoute(
          builder: (context) =>
              showTodoItemScreen(
                  context, itemId: itemId, todoListBloc: bloc)
      ),
    );
  }
}

void _backgroundCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  const MethodChannel BACKGROUND_METHOD_CHANNEL = const MethodChannel(NOTIFICATION_FFI_BG_CHANNEL_NAME);
  BACKGROUND_METHOD_CHANNEL.setMethodCallHandler((call) async {
    switch (call.method) {
      case NOTIFICATION_FFI_COMPLETE_ITEM:
        _completeItem(await TodoRepositorySqflite.getInstance(), call.arguments as int);
        break;
      case NOTIFICATION_FFI_RESTORE_ALARMS:
        _restoreAlarms(await TodoRepositorySqflite.getInstance());
        break;
    }
  });
  BACKGROUND_METHOD_CHANNEL.invokeMethod(NOTIFICATION_FFI_READY);
}

Future<void> _completeItem<R extends TodoRepository>(R repository, int itemId) async {
  var item = await repository.getTodoItem(itemId);
  await cancelRemindersForItem(item, repository);
  var newItem = item.toggleCompleted();
  await repository.updateTodoItem(newItem);
  repository.triggerUpdate();
}

Future<void> _restoreAlarms<R extends TodoRepository>(R repository) async {
  var reminders = await repository.getActiveReminders();
  for (final r in reminders) {
    var itemId = await repository.getItemOfReminder(r.id);
    var item = await repository.getTodoItem(itemId);
    await NotificationFFI.setReminder(item, r);
  }
}