import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/screens/todo_item_screen.dart';
import 'package:qunderlist/screens/todo_list_screen.dart';

const String NOTIFICATION_FFI_CHANNEL_NAME = "com.torweb.qunderlist.notification_ffi_channel";

const String NOTIFICATION_FFI_NOTIFICATION_CALLBACK = "notification_callback";
const String NOTIFICATION_FFI_RELOAD_DB = "reload_db";

const String NOTIFICATION_FFI_SET_REMINDER = "set_reminder";
const String NOTIFICATION_FFI_UPDATE_REMINDER = "update_reminder";
const String NOTIFICATION_FFI_DELETE_REMINDER = "delete_reminder";
const String NOTIFICATION_FFI_READY = "ready";

const String NOTIFICATION_FFI_REMINDER_ID = "id";
const String NOTIFICATION_FFI_REMINDER_TIME = "at";

class NotificationFFI {
  static const MethodChannel METHOD_CHANNEL = const MethodChannel(NOTIFICATION_FFI_CHANNEL_NAME);

  static NotificationFFI _notificationFFI;
  factory NotificationFFI(BuildContext context) {
    if (_notificationFFI == null) {
      _notificationFFI = NotificationFFI._internal(context);
    }
    return _notificationFFI;
  }

  NotificationFFI._internal(this._context) {
    _setMethodCallHandler();
  }

  BuildContext _context;

  void ready() {
    METHOD_CHANNEL.invokeMethod(NOTIFICATION_FFI_READY);
  }

  static Future<void> setReminder(Reminder reminder) {
    var args = { NOTIFICATION_FFI_REMINDER_ID: reminder.id, NOTIFICATION_FFI_REMINDER_TIME: reminder.at.millisecondsSinceEpoch };
    METHOD_CHANNEL.invokeMethod(NOTIFICATION_FFI_SET_REMINDER, args);
  }

  static Future<void> updateReminder(Reminder reminder) {
    var args = { NOTIFICATION_FFI_REMINDER_ID: reminder.id, NOTIFICATION_FFI_REMINDER_TIME: reminder.at.millisecondsSinceEpoch };
    METHOD_CHANNEL.invokeMethod(NOTIFICATION_FFI_UPDATE_REMINDER, args);
  }

  static Future<void> cancelReminder(int reminderId) {
    return METHOD_CHANNEL.invokeMethod(NOTIFICATION_FFI_DELETE_REMINDER, reminderId);
  }

  void _setMethodCallHandler() {
    METHOD_CHANNEL.setMethodCallHandler((call) async {
      switch (call.method) {
        case NOTIFICATION_FFI_NOTIFICATION_CALLBACK:
          var id = call.arguments as int;
          _notificationCallback(id);
          break;
        case NOTIFICATION_FFI_RELOAD_DB:
          _reloadDB();
          break;
      }
    });
  }

  Future<void> _notificationCallback(int itemId) async {
    var repository = RepositoryProvider.of<TodoRepository>(_context);
    var list = (await repository.getListsOfItem(itemId)).first;
    var bloc = TodoListBloc(repository, list, filter: TodoStatusFilter.active);
    bloc.add(GetDataEvent(filter: TodoStatusFilter.active));
    var navigator = Navigator.of(_context);
    navigator.pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) => showTodoListScreenExternal(context, repository, bloc)
        ),
            (route) => route.settings.name == "/"
    );
    navigator.push(
      MaterialPageRoute(
          builder: (context) => showTodoItemScreen(context, repository, itemId: itemId, todoListBloc: bloc)
      ),
    );
  }

  void _reloadDB() {
    var repository = RepositoryProvider.of<TodoRepository>(_context);
    repository.triggerUpdate();
  }
}