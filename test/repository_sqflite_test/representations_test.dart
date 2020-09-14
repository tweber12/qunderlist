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
    var resultItem = todoItemFromRepresentation(representation, []);
    expect(resultItem, item);
  });

  test('item representation test full', () async {
    var now = DateTime.now();
    var reminders = [Reminder(now), Reminder(now.add(Duration(days: 1)))];
    TodoItem item = TodoItem("test name", now, completedOn: now, dueDate: now, note: "test note", priority: TodoPriority.high, reminders: reminders);
    var representation = todoItemToRepresentation(item);
    var resultItem = todoItemFromRepresentation(representation, reminders);
    expect(resultItem, item);
  });


  test('item short representation test minimal', () async {
    TodoItemShort item = TodoItemShort("test name", DateTime.now());
    var representation = todoItemToRepresentation(item);
    var resultItem = todoItemShortFromRepresentation(representation, 0);
    expect(resultItem, item);
  });

  test('item short representation test full', () async {
    var now = DateTime.now();
    TodoItemShort item = TodoItemShort("test name", now, completedOn: now, dueDate: now, note: "test note", priority: TodoPriority.high, nActiveReminders: 5);
    var representation = todoItemToRepresentation(item);
    var resultItem = todoItemShortFromRepresentation(representation, 5);
    expect(resultItem, item);
  });

  test('item representation test id', () async {
    TodoItem item = TodoItem("test name", DateTime.now(), id: 8);
    var representation = todoItemToRepresentation(item);
    representation[ID] = 8;
    var resultItem = todoItemFromRepresentation(representation, []);
    expect(resultItem, item);
  });
}