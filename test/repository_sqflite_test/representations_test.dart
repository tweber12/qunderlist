import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';

void main() {
  test('list representation test', () async {
    TodoList list = TodoList("test name", Palette.green);
    var representation = todoListToRepresentation(list);
    var resultList = todoListFromRepresentation(representation);
    expect(resultList, list);
  });

  test('list representation test id', () async {
    // The id of the list is not included in the representation of the list
    TodoList list = TodoList("test name", Palette.green, id: 8);
    var representation = todoListToRepresentation(list);
    representation[ID] = list.id;
    var resultList = todoListFromRepresentation(representation);
    expect(resultList, list);
  });


  test('list representation test ordering', () async {
    TodoList list = TodoList("test name", Palette.green);
    var representation = todoListToRepresentation(list, ordering: 8);
    expect(representation[TODO_LIST_ORDERING], 8);
  });

  test('reminder representation test', () async {
    Reminder reminder = Reminder(DateTime.now());
    var representation = reminderToRepresentation(reminder);
    var resultReminder = reminderFromRepresentation(representation);
    expect(resultReminder, reminder);
  });

  test('reminder representation test id', () async {
    // The id of the reminder is not included in its representation
    Reminder reminder = Reminder(DateTime.now(), id: 8);
    var representation = reminderToRepresentation(reminder);
    representation[ID] = reminder.id;
    var resultReminder = reminderFromRepresentation(representation);
    expect(resultReminder, reminder);
  });

  test('item representation test minimal', () async {
    TodoItem item = TodoItem("test name", DateTime.now());
    var representation = todoItemToRepresentation(item);
    var resultItem = todoItemFromRepresentation(representation, [], []);
    expect(resultItem, item);
  });

  test('item representation test full', () async {
    var now = DateTime.now();
    var reminders = [Reminder(now), Reminder(now.add(Duration(days: 1)))];
    var lists = [TodoList("Title", Palette.brown), TodoList("Magic list", Palette.deepOrange), TodoList("Extra list", Palette.lime)];
    TodoItem item = TodoItem("test name", now, completedOn: now, dueDate: now, note: "test note", priority: TodoPriority.high, reminders: reminders, repeated: Repeated(true, false, true, true, RepeatedStepDaily(1)), onLists: lists);
    var representation = todoItemToRepresentation(item);
    representation.addAll(repeatedToRepresentation(item.repeated));
    var resultItem = todoItemFromRepresentation(representation, reminders, lists);
    expect(resultItem, item);
  });


  test('item short representation test minimal', () async {
    var item = TodoItem("test name", DateTime.now());
    var representation = todoItemToRepresentation(item);
    var resultItem = todoItemShortFromRepresentation(representation, 0);
    expect(resultItem, item.shorten());
  });

  test('item short representation test full', () async {
    var now = DateTime.now();
    var reminders = [Reminder(now), Reminder(now.add(Duration(days: 1)))];
    TodoItem item = TodoItem("test name", now, completedOn: now, dueDate: now, note: "test note", priority: TodoPriority.high, reminders: reminders, repeated: Repeated(true, false, true, true, RepeatedStepDaily(1)));
    var representation = todoItemToRepresentation(item);
    representation.addAll(repeatedToRepresentation(item.repeated));
    var resultItem = todoItemShortFromRepresentation(representation, item.nActiveReminders);
    expect(resultItem, item.shorten());
  });

  test('item representation test id', () async {
    TodoItem item = TodoItem("test name", DateTime.now(), id: 8);
    var representation = todoItemToRepresentation(item);
    representation[ID] = 8;
    var resultItem = todoItemFromRepresentation(representation, [], []);
    expect(resultItem, item);
  });

  test('bool representation true', () async {
    expect(boolFromRepresentation(boolToRepresentation(true)), true);
  });

  test('bool representation false', () async {
    expect(boolFromRepresentation(boolToRepresentation(false)), false);
  });

  test('repeated step daily', () async {
    var step = RepeatedStepDaily(4);
    expect(repeatedStepFromRepresentation(repeatedStepToRepresentation(step)), step);
  });

  test('repeated step weekly', () async {
    var step = RepeatedStepWeekly(3);
    expect(repeatedStepFromRepresentation(repeatedStepToRepresentation(step)), step);
  });

  test('repeated step monthly', () async {
    var step = RepeatedStepMonthly(3, 17);
    expect(repeatedStepFromRepresentation(repeatedStepToRepresentation(step)), step);
  });

  test('repeated step yearly', () async {
    var step = RepeatedStepYearly(1, 4, 23);
    expect(repeatedStepFromRepresentation(repeatedStepToRepresentation(step)), step);
  });

  test('repeated order 1', () async {
    var repeated = Repeated(true, true, false, false, RepeatedStepMonthly(1,3));
    expect(repeatedFromRepresentation(repeatedToRepresentation(repeated)), repeated);
  });

  test('repeated order 2', () async {
    var repeated = Repeated(false, true, false, true, RepeatedStepDaily(1));
    expect(repeatedFromRepresentation(repeatedToRepresentation(repeated)), repeated);
  });

  test('repeated order 3', () async {
    var repeated = Repeated(true, false, false, true, RepeatedStepMonthly(1,3));
    expect(repeatedFromRepresentation(repeatedToRepresentation(repeated)), repeated);
  });

  test('repeated order 4', () async {
    var repeated = Repeated(true, false, true, true, RepeatedStepMonthly(1,3));
    expect(repeatedFromRepresentation(repeatedToRepresentation(repeated)), repeated);
  });

  test('repeated null', () async {
    expect(repeatedFromRepresentation(repeatedToRepresentation(null)), null);
  });

  test('repeated null repr', () async {
    expect(repeatedFromRepresentation({TODO_ITEM_REPEAT_ACTIVE: null}), null);
  });

  test('repeated null repr empty', () async {
    expect(repeatedFromRepresentation({}), null);
  });

  test('repeated state none', () {
    expect(repeatedStatusFromRepresentation({TODO_ITEM_REPEAT_ACTIVE: null}), RepeatedStatus.none);
  });

  test('repeated state active', () async {
    var repeated = Repeated(true, false, false, false, RepeatedStepMonthly(1,3));
    expect(repeatedStatusFromRepresentation(repeatedToRepresentation(repeated)), RepeatedStatus.active);
  });

  test('repeated state inactive', () async {
    var repeated = Repeated(false, false, false, false, RepeatedStepMonthly(1,3));
    expect(repeatedStatusFromRepresentation(repeatedToRepresentation(repeated)), RepeatedStatus.inactive);
  });
}