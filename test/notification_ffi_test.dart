import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/notification_ffi.dart';
import 'package:qunderlist/repository/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("send", () {
    NotificationFFI notificationFFI;

    setUp(() {
      notificationFFI = NotificationFFI(channelName: "test_channel");
    });

    test("init", () {
      int initArg;
      bool readyCalled = false;
      notificationFFI.setMockMethodCallHandler((call) {
        if (call.method == NOTIFICATION_FFI_INIT) {
          expect(readyCalled, false, reason: "Ready called before init");
          initArg = call.arguments;
        } else if (call.method == NOTIFICATION_FFI_READY) {
          readyCalled = true;
        } else {
          throw call.method;
        }
      });
      notificationFFI.init(12);
      expect(initArg, 12);
    });

    test("ready", () {
      bool readyCalled = false;
      notificationFFI.setMockMethodCallHandler((call) {
        if (call.method == NOTIFICATION_FFI_READY) {
          readyCalled = true;
        } else {
          throw call.method;
        }
      });
      notificationFFI.ready();
      expect(readyCalled, true);
    });

    test("setReminder", () {
      var setReminderArgs;
      notificationFFI.setMockMethodCallHandler((call) {
        if (call.method == NOTIFICATION_FFI_SET_REMINDER) {
          setReminderArgs = call.arguments;
        } else {
          throw call.method;
        }
      });
      var time = DateTime(2020, 11, 4, 15, 44);
      var arguments = {
        NOTIFICATION_FFI_ITEM_ID: 8,
        NOTIFICATION_FFI_ITEM_TITLE: "test",
        NOTIFICATION_FFI_ITEM_NOTE: "note",
        NOTIFICATION_FFI_REMINDER_TIME: time.millisecondsSinceEpoch,
        NOTIFICATION_FFI_REMINDER_ID: 1
      };
      notificationFFI.setReminder(
          TodoItemShort(arguments[NOTIFICATION_FFI_ITEM_TITLE], DateTime.now(), note: arguments[NOTIFICATION_FFI_ITEM_NOTE], id: arguments[NOTIFICATION_FFI_ITEM_ID]),
          Reminder(time, id: arguments[NOTIFICATION_FFI_REMINDER_ID])
      );
      expect(setReminderArgs, arguments);
    });

    test("updateReminder", () {
      var updateReminderArgs;
      notificationFFI.setMockMethodCallHandler((call) {
        if (call.method == NOTIFICATION_FFI_UPDATE_REMINDER) {
          updateReminderArgs = call.arguments;
        } else {
          throw call.method;
        }
      });
      var time = DateTime(2020, 11, 4, 15, 44);
      var arguments = {
        NOTIFICATION_FFI_ITEM_ID: 8,
        NOTIFICATION_FFI_ITEM_TITLE: "test",
        NOTIFICATION_FFI_ITEM_NOTE: "note",
        NOTIFICATION_FFI_REMINDER_TIME: time.millisecondsSinceEpoch,
        NOTIFICATION_FFI_REMINDER_ID: 1
      };
      notificationFFI.updateReminder(
          TodoItemShort(arguments[NOTIFICATION_FFI_ITEM_TITLE], DateTime.now(), note: arguments[NOTIFICATION_FFI_ITEM_NOTE], id: arguments[NOTIFICATION_FFI_ITEM_ID]),
          Reminder(time, id: arguments[NOTIFICATION_FFI_REMINDER_ID])
      );
      expect(updateReminderArgs, arguments);
    });

    test("deleteReminder", () {
      var deleteReminderArgs;
      notificationFFI.setMockMethodCallHandler((call) {
        if (call.method == NOTIFICATION_FFI_DELETE_REMINDER) {
          deleteReminderArgs = call.arguments;
        } else {
          throw call.method;
        }
      });
      notificationFFI.cancelReminder(9);
      expect(deleteReminderArgs, 9);
    });
  });

  group("receive", () {
    NotificationFFI notificationFFI;
    int callbackId;
    int completeId;
    bool restoreCalled;

    setUp(() {
      callbackId = null;
      completeId = null;
      restoreCalled = false;
      notificationFFI = NotificationFFI(
          channelName: "test_channel_receive",
          notificationCallback: (int itemId) { callbackId = itemId; },
          completeItemCallback: (int itemId) { completeId = itemId; },
          restoreAlarmsCallback: () { restoreCalled = true; },
      );
    });

    test("notificationCallback", () {
      notificationFFI.methodCallHandler(MethodCall(NOTIFICATION_FFI_NOTIFICATION_CALLBACK, 7));
      expect(callbackId, 7);
      expect(completeId, null);
      expect(restoreCalled, false);
    });

    test("completeItem", () {
      notificationFFI.methodCallHandler(MethodCall(NOTIFICATION_FFI_COMPLETE_ITEM, 3));
      expect(callbackId, null);
      expect(completeId, 3);
      expect(restoreCalled, false);
    });

    test("restoreAlarms", () {
      notificationFFI.methodCallHandler(MethodCall(NOTIFICATION_FFI_RESTORE_ALARMS));
      expect(callbackId, null);
      expect(completeId, null);
      expect(restoreCalled, true);
    });
  });
}