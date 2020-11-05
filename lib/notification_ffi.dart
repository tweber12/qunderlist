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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qunderlist/repository/models.dart';

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
  static Map<String,NotificationFFI> _singletons = Map();

  final String channelName;
  final MethodChannel channel;

  final Function(int) notificationCallback;
  final Function(int) completeItemCallback;
  final Function() restoreAlarmsCallback;

  factory NotificationFFI({
      @required String channelName,
      Function(int) notificationCallback,
      Function(int) completeItemCallback,
      Function() restoreAlarmsCallback
    }) {
    var ffi = _singletons[channelName];
    if (ffi != null) {
      return ffi;
    } else {
      ffi = NotificationFFI._internal(
          channelName: channelName,
          notificationCallback: notificationCallback,
          completeItemCallback: completeItemCallback,
          restoreAlarmsCallback: restoreAlarmsCallback
      );
      _singletons[channelName] = ffi;
      return ffi;
    }
  }

  NotificationFFI._internal({
    @required String channelName,
    this.notificationCallback,
    this.completeItemCallback,
    this.restoreAlarmsCallback
  }):
        this.channelName = channelName,
        channel = MethodChannel(channelName)
  {
    channel.setMethodCallHandler(methodCallHandler);
  }

  void setMockMethodCallHandler(Function(MethodCall call) handler) {
    channel.setMockMethodCallHandler(handler);
  }

  Future<void> init(int callbackHandle) async {
    await channel.invokeMethod(NOTIFICATION_FFI_INIT, callbackHandle);
    return ready();
  }

  Future<void> ready() {
    return channel.invokeMethod(NOTIFICATION_FFI_READY);
  }

  Future<void> setReminder(TodoItemBase item, Reminder reminder) {
    var args = {
      NOTIFICATION_FFI_REMINDER_ID: reminder.id,
      NOTIFICATION_FFI_REMINDER_TIME: reminder.at.millisecondsSinceEpoch,
      NOTIFICATION_FFI_ITEM_ID: item.id,
      NOTIFICATION_FFI_ITEM_TITLE: item.todo,
      NOTIFICATION_FFI_ITEM_NOTE: item.note
    };
    return channel.invokeMethod(NOTIFICATION_FFI_SET_REMINDER, args);
  }

  Future<void> updateReminder(TodoItemBase item, Reminder reminder) {
    var args = {
      NOTIFICATION_FFI_REMINDER_ID: reminder.id,
      NOTIFICATION_FFI_REMINDER_TIME: reminder.at.millisecondsSinceEpoch,
      NOTIFICATION_FFI_ITEM_ID: item.id,
      NOTIFICATION_FFI_ITEM_TITLE: item.todo,
      NOTIFICATION_FFI_ITEM_NOTE: item.note
    };
    return channel.invokeMethod(NOTIFICATION_FFI_UPDATE_REMINDER, args);
  }

  Future<void> cancelReminder(int reminderId) {
    return channel.invokeMethod(NOTIFICATION_FFI_DELETE_REMINDER, reminderId);
  }

  Future<void> methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case NOTIFICATION_FFI_NOTIFICATION_CALLBACK:
        var id = call.arguments as int;
        notificationCallback(id);
        break;
      case NOTIFICATION_FFI_COMPLETE_ITEM:
        completeItemCallback(call.arguments as int);
        break;
      case NOTIFICATION_FFI_RESTORE_ALARMS:
        restoreAlarmsCallback();
        break;
    }
  }
}

NotificationFFI notificationFFIInitialize({
  @required String channelName,
  Function(int) notificationCallback,
  Function(int) completeItemCallback,
  Function() restoreAlarmsCallback
}) {
  return NotificationFFI(
      channelName: channelName,
      notificationCallback: notificationCallback,
      completeItemCallback: completeItemCallback,
      restoreAlarmsCallback: restoreAlarmsCallback
  );
}