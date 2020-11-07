import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:qunderlist/blocs/base.dart';
import 'package:qunderlist/blocs/repeated.dart';
import 'package:qunderlist/notification_ffi.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/repository/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("foreground", () {
    TodoRepository repository;
    NotificationHandler notificationHandler;
    MockNotificationFFI ffi;
    BaseBloc bloc = MockBaseBloc();

    MockNotificationFFI initMockFFI({
      String channelName,
      Function(int) notificationCallback,
      Function(int) completeItemCallback,
      Function() restoreAlarmsCallback,
      Function(int) createNextCallback,
    }) {
      ffi = MockNotificationFFI(notificationCallback, completeItemCallback, restoreAlarmsCallback, createNextCallback);
      return ffi;
    }

    setUp(() async {
      repository = MockTodoRepository();
      notificationHandler = NotificationHandler.foreground(repository);
      notificationHandler.init(bloc, initializer: initMockFFI);
      verify(ffi.init(any));
    });

    group("send", () {
      test("setReminder", () async {
        var item = TodoItemShort("foo", DateTime.now());
        var reminder = Reminder(DateTime(2020, 11, 5, 9, 47), id: 9);
        await notificationHandler.setReminder(item, reminder);
        verify(ffi.setReminder(item, reminder));
        verifyNoMoreInteractions(ffi);
      });

      test("updateReminder", () async {
        var item = TodoItemShort("foo", DateTime.now());
        var reminder = Reminder(DateTime(2020, 11, 5, 9, 47), id: 9);
        await notificationHandler.updateReminder(item, reminder);
        verify(ffi.updateReminder(item, reminder));
        verifyNoMoreInteractions(ffi);
      });

      test("deleteReminder", () async {
        await notificationHandler.cancelReminder(7);
        verify(ffi.cancelReminder(7));
        verifyNoMoreInteractions(ffi);
      });

      test("setRemindersForItem with item", () async {
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 10, 3, 10, 19), id: 7)
        ];
        var item = TodoItem("test", DateTime.now(), reminders: reminders);
        await notificationHandler.setRemindersForItem(item);
        verifyZeroInteractions(repository);
        verify(ffi.setReminder(item, reminders[0]));
        verify(ffi.setReminder(item, reminders[1]));
        verifyNoMoreInteractions(ffi);
      });

      test("setRemindersForItem with shortitem", () async {
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 10, 3, 10, 19), id: 7)
        ];
        var item = TodoItemShort("test", DateTime.now(), id: 3, nActiveReminders: 0);
        when(repository.getRemindersForItem(item.id)).thenAnswer((_) => Future.value(reminders));
        await notificationHandler.setRemindersForItem(item);
        verify(repository.getRemindersForItem(item.id));
        verify(ffi.setReminder(item, reminders[0]));
        verify(ffi.setReminder(item, reminders[1]));
        verifyNoMoreInteractions(ffi);
      });

      test("cancelRemindersForItem with item", () async {
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 10, 3, 10, 19), id: 7)
        ];
        var item = TodoItem("test", DateTime.now(), reminders: reminders);
        await notificationHandler.cancelRemindersForItem(item);
        verifyZeroInteractions(repository);
        verify(ffi.cancelReminder(reminders[0].id));
        verify(ffi.cancelReminder(reminders[1].id));
        verifyNoMoreInteractions(ffi);
      });

      test("cancelRemindersForItem with shortitem", () async {
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 10, 3, 10, 19), id: 7)
        ];
        var item = TodoItemShort("test", DateTime.now(), id: 3, nActiveReminders: 0);
        when(repository.getRemindersForItem(item.id)).thenAnswer((_) => Future.value(reminders));
        await notificationHandler.cancelRemindersForItem(item);
        verify(repository.getRemindersForItem(item.id));
        verify(ffi.cancelReminder(reminders[0].id));
        verify(ffi.cancelReminder(reminders[1].id));
        verifyNoMoreInteractions(ffi);
      });

      test("cancelRemindersForList", () async {
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 10, 3, 10, 19), id: 7)
        ];
        var list = TodoList("foo", Palette.blue, id: 3);
        when(repository.getActiveRemindersForList(list.id)).thenAnswer((_) => Future.value(reminders));
        await notificationHandler.cancelRemindersForList(list);
        verify(repository.getActiveRemindersForList(list.id));
        verify(ffi.cancelReminder(reminders[0].id));
        verify(ffi.cancelReminder(reminders[1].id));
        verifyNoMoreInteractions(ffi);
      });

      test("setPendingItem with next after due date", () async {
        var repeated = Repeated(true, true, false, true, RepeatedStepDaily(3));
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 11, 9, 10, 19), id: 7)
        ];
        var item = TodoItem("title", DateTime.now(), dueDate: DateTime(2020, 11, 3), id: 7, repeated: repeated, reminders: reminders);
        var next = nextItem(item);
        await notificationHandler.setPendingItem(item, next: next);
        verify(ffi.setPendingItemAlarm(alarmId(item.id), item.id, DateTime(2020, 11, 4)));
        verify(ffi.setReminder(next, next.reminders[0].withId(reminderId(reminders[0].id))));
        verify(ffi.setReminder(next, next.reminders[1].withId(reminderId(reminders[1].id))));
      });

      test("setPendingItem with next before due date", () async {
        var repeated = Repeated(true, true, false, true, RepeatedStepDaily(3));
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 11, 9, 10, 19), id: 7)
        ];
        var item = TodoItem("title", DateTime.now(), dueDate: DateTime(2020, 11, 13), id: 7, repeated: repeated, reminders: reminders);
        var next = nextItem(item);
        await notificationHandler.setPendingItem(item, next: next);
        verify(ffi.setPendingItemAlarm(alarmId(item.id), item.id, DateTime(2020, 11, 8)));
        verify(ffi.setReminder(next, next.reminders[0].withId(reminderId(reminders[0].id))));
        verify(ffi.setReminder(next, next.reminders[1].withId(reminderId(reminders[1].id))));
      });

      test("setPendingItem without next after due date", () async {
        var repeated = Repeated(true, true, false, true, RepeatedStepDaily(3));
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 11, 9, 10, 19), id: 7)
        ];
        var item = TodoItem("title", DateTime.now(), dueDate: DateTime(2020, 11, 3), id: 7, repeated: repeated, reminders: reminders);
        var next = nextItem(item);
        await notificationHandler.setPendingItem(item);
        verify(ffi.setPendingItemAlarm(alarmId(item.id), item.id, DateTime(2020, 11, 4)));
        verify(ffi.setReminder(any, next.reminders[0].withId(reminderId(reminders[0].id))));
        verify(ffi.setReminder(any, next.reminders[1].withId(reminderId(reminders[1].id))));
      });

      test("setPendingItem without next after due date", () async {
        var repeated = Repeated(true, true, false, true, RepeatedStepDaily(3));
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 11, 9, 10, 19), id: 7)
        ];
        var item = TodoItem("title", DateTime.now(), dueDate: DateTime(2020, 11, 13), id: 7, repeated: repeated, reminders: reminders);
        var next = nextItem(item);
        await notificationHandler.setPendingItem(item);
        verify(ffi.setPendingItemAlarm(alarmId(item.id), item.id, DateTime(2020, 11, 8)));
        verify(ffi.setReminder(any, next.reminders[0].withId(reminderId(reminders[0].id))));
        verify(ffi.setReminder(any, next.reminders[1].withId(reminderId(reminders[1].id))));
      });

      test("cancelPendingItem with next", () async {
        var repeated = Repeated(true, true, false, true, RepeatedStepDaily(3));
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 11, 9, 10, 19), id: 7)
        ];
        var item = TodoItem("title", DateTime.now(), dueDate: DateTime(2020, 11, 3), id: 7, repeated: repeated, reminders: reminders);
        var next = nextItem(item);
        await notificationHandler.cancelPendingItem(item, next: next);
        verify(ffi.cancelPendingItemAlarm(alarmId(item.id)));
        verify(ffi.cancelReminder(reminderId(reminders[0].id)));
        verify(ffi.cancelReminder(reminderId(reminders[1].id)));
      });

      test("cancelPendingItem without next", () async {
        var repeated = Repeated(true, true, false, true, RepeatedStepDaily(3));
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 11, 9, 10, 19), id: 7)
        ];
        var item = TodoItem("title", DateTime.now(), dueDate: DateTime(2020, 11, 3), id: 7, repeated: repeated, reminders: reminders);
        await notificationHandler.cancelPendingItem(item);
        verify(ffi.cancelPendingItemAlarm(alarmId(item.id)));
        verify(ffi.cancelReminder(reminderId(reminders[0].id)));
        verify(ffi.cancelReminder(reminderId(reminders[1].id)));
      });
    });
    
    group("receive", () {
      test("notificationCallback", () async {
        var itemId;
        var list = TodoList("foo", Palette.pink, id: 7);
        when(repository.getListsOfItem(itemId)).thenAnswer((_) => Future.value([list]));
        await ffi.notificationCallback(itemId);
        verify(repository.getListsOfItem(itemId));
        verify(bloc.add(BaseShowItemEvent(itemId, listId: list.id, list: list)));
        verifyNoMoreInteractions(bloc);
        verifyNoMoreInteractions(repository);
        verifyNoMoreInteractions(ffi);
      });

      test("completeItem active", () async {
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 10, 3, 10, 19), id: 7)
        ];
        var itemId = 12;
        var item = TodoItem("test", DateTime.now(), reminders: reminders, id: itemId);
        when(repository.getTodoItem(itemId)).thenAnswer((realInvocation) => Future.value(item));
        await ffi.completeItemCallback(itemId);
        verify(repository.getTodoItem(itemId));
        var updated = verify(repository.updateTodoItem(captureAny)).captured.single;
        expect(updated.id, item.id);
        expect(updated.todo, item.todo);
        expect(updated.completedOn, isNotNull);
        verify(ffi.cancelReminder(reminders[0].id));
        verify(ffi.cancelReminder(reminders[1].id));
      });

      test("completeItem completed", () async {
        var reminders = [
          Reminder(DateTime(2020, 11, 5, 9, 47), id: 9),
          Reminder(DateTime(2020, 10, 3, 10, 19), id: 7)
        ];
        var itemId = 12;
        var item = TodoItem("test", DateTime.now(), completedOn: DateTime.now(), reminders: reminders, id: itemId);
        when(repository.getTodoItem(itemId)).thenAnswer((realInvocation) => Future.value(item));
        await ffi.completeItemCallback(itemId);
        verify(repository.getTodoItem(itemId));
        verifyNoMoreInteractions(repository);
        verifyNoMoreInteractions(ffi);
      });

      test("restoreAlarms", () async {
        var reminders = [
          Reminder(DateTime.now().add(Duration(days: 3)), id: 9),
          Reminder(DateTime.now().add(Duration(hours: 5)), id: 7),
          Reminder(DateTime.now().subtract(Duration(hours: 1)), id: 8),
          Reminder(DateTime.now().add(Duration(hours: 5)), id: 2),
          Reminder(DateTime.now().subtract(Duration(days: 25)), id: 4),
        ];
        var items = [
          TodoItem("first item", DateTime.now(), reminders: [reminders[0], reminders[3]], id: 1),
          TodoItem("second item", DateTime.now(), completedOn: DateTime.now(), reminders: [reminders[1]], id: 2),
          TodoItem("third item", DateTime.now(), reminders: [reminders[4], reminders[2]], id: 3),
        ];
        when(repository.getActiveReminders()).thenAnswer((realInvocation) => Future.value(reminders));
        when(repository.getItemOfReminder(reminders[0].id)).thenAnswer((_) => Future.value(items[0].id));
        when(repository.getItemOfReminder(reminders[1].id)).thenAnswer((_) => Future.value(items[1].id));
        when(repository.getItemOfReminder(reminders[2].id)).thenAnswer((_) => Future.value(items[2].id));
        when(repository.getItemOfReminder(reminders[3].id)).thenAnswer((_) => Future.value(items[0].id));
        when(repository.getItemOfReminder(reminders[4].id)).thenAnswer((_) => Future.value(items[2].id));
        when(repository.getTodoItem(1)).thenAnswer((_) => Future.value(items[0]));
        when(repository.getTodoItem(2)).thenAnswer((_) => Future.value(items[1]));
        when(repository.getTodoItem(3)).thenAnswer((_) => Future.value(items[2]));
        await ffi.restoreAlarmsCallback();
        verify(ffi.setReminder(items[0], reminders[0]));
        verify(ffi.setReminder(items[2], reminders[2]));
        verify(ffi.setReminder(items[0], reminders[3]));
        verify(ffi.setReminder(items[2], reminders[4]));
        verifyNoMoreInteractions(ffi);
      });

      test("create next", () async {
        var itemId = 7;
        var repeated = Repeated(true, true, false, true, RepeatedStepDaily(3));
        var now = DateTime.now();
        var nowDay = DateTime(now.year, now.month, now.day);
        var reminders = [
          Reminder(nowDay.add(Duration(days: 5, hours: 8, minutes: 24)), id: 9),
          Reminder(nowDay.add(Duration(days: 8, hours: 14, minutes: 45)), id: 7)
        ];
        var dueDate = nowDay.add(Duration(days: 2));
        var item = TodoItem("title", DateTime.now(), dueDate: dueDate, id: itemId, repeated: repeated, reminders: reminders);
        var nextId = 8;
        var nextReminders = [
          Reminder(reminders[0].at.add(Duration(days: 3)), id: 12),
          Reminder(reminders[1].at.add(Duration(days: 3)), id: 13)
        ];
        var next = TodoItem("title", DateTime.now(), dueDate: item.dueDate.add(Duration(days: 3)), id: nextId, repeated: repeated, reminders: nextReminders);
        when(repository.getTodoItem(itemId)).thenAnswer((_) => Future.value(item));
        when(repository.addTodoItem(any)).thenAnswer((_) => Future.value(next));
        await ffi.createNextCallback(itemId);
        verify(repository.getTodoItem(itemId));
        var added = verify(repository.addTodoItem(captureAny)).captured.single;
        expect(added.todo, item.todo);
        expect(added.repeated, item.repeated);
        expect(added.dueDate, next.dueDate);
        expect(added.reminders[0].at, nextReminders[0].at);
        expect(added.reminders[1].at, nextReminders[1].at);
        verify(ffi.cancelReminder(reminderId(reminders[0].id)));
        verify(ffi.cancelReminder(reminderId(reminders[1].id)));
        verify(ffi.setReminder(next, nextReminders[0]));
        verify(ffi.setReminder(next, nextReminders[1]));
        verify(ffi.setPendingItemAlarm(alarmId(next.id), next.id, next.dueDate.add(Duration(days: 1))));
        verify(repository.triggerUpdate());
        verifyNoMoreInteractions(repository);
      });

      test("create next auto complete", () async {
        var itemId = 7;
        var repeated = Repeated(true, true, true, true, RepeatedStepDaily(3));
        var now = DateTime.now();
        var nowDay = DateTime(now.year, now.month, now.day);
        var reminders = [
          Reminder(nowDay.add(Duration(days: 5, hours: 8, minutes: 24)), id: 9),
          Reminder(nowDay.add(Duration(days: 8, hours: 14, minutes: 45)), id: 7)
        ];
        var dueDate = nowDay.add(Duration(days: 2));
        var item = TodoItem("title", DateTime.now(), dueDate: dueDate, id: itemId, repeated: repeated, reminders: reminders);
        var nextId = 8;
        var nextReminders = [
          Reminder(reminders[0].at.add(Duration(days: 3)), id: 12),
          Reminder(reminders[1].at.add(Duration(days: 3)), id: 13)
        ];
        var next = TodoItem("title", DateTime.now(), dueDate: item.dueDate.add(Duration(days: 3)), id: nextId, repeated: repeated, reminders: nextReminders);
        when(repository.getTodoItem(itemId)).thenAnswer((_) => Future.value(item));
        when(repository.addTodoItem(any)).thenAnswer((_) => Future.value(next));
        await ffi.createNextCallback(itemId);
        verify(repository.getTodoItem(itemId));
        var completed = verify(repository.updateTodoItem(captureAny)).captured.single;
        expect(completed.id, item.id);
        expect(completed.completedOn, isNotNull);
        var added = verify(repository.addTodoItem(captureAny)).captured.single;
        expect(added.todo, item.todo);
        expect(added.repeated, item.repeated);
        expect(added.dueDate, next.dueDate);
        expect(added.reminders[0].at, nextReminders[0].at);
        expect(added.reminders[1].at, nextReminders[1].at);
        verify(ffi.cancelReminder(reminderId(reminders[0].id)));
        verify(ffi.cancelReminder(reminderId(reminders[1].id)));
        verify(ffi.setReminder(next, nextReminders[0]));
        verify(ffi.setReminder(next, nextReminders[1]));
        verify(ffi.setPendingItemAlarm(alarmId(next.id), next.id, next.dueDate.add(Duration(days: 1))));
        verify(repository.triggerUpdate());
        verifyNoMoreInteractions(repository);
      });

      test("create next auto complete no history", () async {
        var itemId = 7;
        var repeated = Repeated(true, true, true, false, RepeatedStepDaily(3));
        var now = DateTime.now();
        var nowDay = DateTime(now.year, now.month, now.day);
        var reminders = [
          Reminder(nowDay.add(Duration(days: 5, hours: 8, minutes: 24)), id: 9),
          Reminder(nowDay.add(Duration(days: 8, hours: 14, minutes: 45)), id: 7)
        ];
        var dueDate = nowDay.add(Duration(days: 2));
        var item = TodoItem("title", DateTime.now(), dueDate: dueDate, id: itemId, repeated: repeated, reminders: reminders);
        var nextId = 8;
        var nextReminders = [
          Reminder(reminders[0].at.add(Duration(days: 3)), id: 12),
          Reminder(reminders[1].at.add(Duration(days: 3)), id: 13)
        ];
        var next = TodoItem("title", DateTime.now(), dueDate: item.dueDate.add(Duration(days: 3)), id: nextId, repeated: repeated, reminders: nextReminders);
        when(repository.getTodoItem(itemId)).thenAnswer((_) => Future.value(item));
        when(repository.addTodoItem(any)).thenAnswer((_) => Future.value(next));
        await ffi.createNextCallback(itemId);
        verify(repository.getTodoItem(itemId));
        verify(repository.deleteTodoItem(item.id));
        var added = verify(repository.addTodoItem(captureAny)).captured.single;
        expect(added.todo, item.todo);
        expect(added.repeated, item.repeated);
        expect(added.dueDate, next.dueDate);
        expect(added.reminders[0].at, nextReminders[0].at);
        expect(added.reminders[1].at, nextReminders[1].at);
        verify(ffi.cancelReminder(reminderId(reminders[0].id)));
        verify(ffi.cancelReminder(reminderId(reminders[1].id)));
        verify(ffi.setReminder(next, nextReminders[0]));
        verify(ffi.setReminder(next, nextReminders[1]));
        verify(ffi.setPendingItemAlarm(alarmId(next.id), next.id, next.dueDate.add(Duration(days: 1))));
        verify(repository.triggerUpdate());
        verifyNoMoreInteractions(repository);
      });
    });

    group("ids", () {
      test("alarm id", () {
        var id = 9;
        expect(alarmId(id), 0x40000009);
      });

      test("reminder id", () {
        var id = 9;
        expect(reminderId(id), 0x80000009);
      });
    });
  });
}

class MockTodoRepository extends Mock implements TodoRepository {}
class MockNotificationFFI extends Mock implements NotificationFFI {
  Function(int) notificationCallback;
  Function(int) completeItemCallback;
  Function() restoreAlarmsCallback;
  Function(int) createNextCallback;
  
  MockNotificationFFI(this.notificationCallback, this.completeItemCallback, this.restoreAlarmsCallback, this.createNextCallback);
}
class MockBaseBloc extends Mock implements BaseBloc {}