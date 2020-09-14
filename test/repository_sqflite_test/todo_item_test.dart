import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/sqflite/reminder.dart';
import 'package:qunderlist/repository/sqflite/todo_item.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Database db;
  TodoRepositorySqflite repository;
  List<TodoItem> items;

  // Init ffi loader if needed.
  sqfliteFfiInit();
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: createDatabase, onConfigure: configureDatabase));
    repository = await TodoRepositorySqflite.getInstance(db: db);
    var dao = TodoItemDao(db);
    var reminderDao = ReminderDao(db);
    var now = DateTime.now();
    items = List();
    items.add(TodoItem("first item", now));
    items.add(TodoItem("second item", now.add(Duration(hours: 1)),
        note: "note for second item", completedOn: now.subtract(Duration(minutes: 1)),
        dueDate: now.add(Duration(days: 1)), priority: TodoPriority.high, reminders: [Reminder(now), Reminder(now.add(Duration(minutes: 5)))]
    ));
    items.add(TodoItem("third item", now.add(Duration(hours: 5)),
      note: "a longer\nnote for the third item\ninthislist",
      dueDate: now.add(Duration(days: 10)), priority: TodoPriority.low,
    ));
    items.add(TodoItem("fourth item", now.add(Duration(days: 80)),
      priority: TodoPriority.medium, reminders: [Reminder(now.add(Duration(days: 25)))]
    ));
    for (int i=0; i<items.length; i++) {
      var item = items[i];
      var id = await dao.addTodoItem(item);
      item = item.copyWith(id: id);
      if (item.reminders != null && item.reminders.isNotEmpty) {
        for (int j=0; j<item.reminders.length; j++) {
          var reminder = item.reminders[j];
          var id = await reminderDao.addReminder(item.id, reminder.at);
          reminder = reminder.withId(id);
          item.reminders[j] = reminder;
        }
      }
      items[i] = item;
    }
  });
  tearDown(() async {
    await db.close();
    db = null;
    repository = null;
    items = null;
  });

  test('persist items test', () async {
    for (final item in items) {
      var resultItem = await repository.getTodoItem(item.id);
      expect(resultItem, item);
    }
  });

  test('delete item test', () async {
    var delId = items[1].id;
    await repository.deleteTodoItem(delId);
    for (final item in items.where((element) => element.id != delId)) {
      var resultItem = await repository.getTodoItem(item.id);
      expect(resultItem, item);
    }
    expect(await repository.getTodoItem(delId), null);
  });


  test('update item test', () async {
    var updateId = items[1].id;
    var updateItem = TodoItem("updated", DateTime.now(), id: updateId);
    await repository.updateTodoItem(updateItem);
    for (final item in items.where((element) => element.id != updateId)) {
      var resultItem = await repository.getTodoItem(item.id);
      expect(resultItem, item);
    }
    // Reminders are not affected by the update
    expect(await repository.getTodoItem(updateId), updateItem.copyWith(reminders: items[1].reminders));
  });
}