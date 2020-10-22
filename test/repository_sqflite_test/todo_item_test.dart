import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Database db;
  TodoRepositorySqflite repository;
  List<TodoList> lists;
  List<TodoItem> items;

  // Init ffi loader if needed.
  sqfliteFfiInit();
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: createDatabase, onConfigure: configureDatabase));
    repository = await TodoRepositorySqflite.getInstance(db: db);
    var now = DateTime.now();
    lists = [
      TodoList("First list", Palette.yellow),
      TodoList("Second list", Palette.green),
      TodoList("jkldaf", Palette.indigo),
    ];
    for (int i=0; i<lists.length; i++) {
      var id = await repository.addTodoList(lists[i]);
      lists[i] = lists[i].withId(id);
    }
    items = List();
    items.add(TodoItem("first item", now, onLists: [lists[0]]));
    items.add(TodoItem("second item", now.add(Duration(hours: 1)),
        note: "note for second item", completedOn: now.subtract(Duration(minutes: 1)),
        dueDate: now.add(Duration(days: 1)), priority: TodoPriority.high, reminders: [Reminder(now), Reminder(now.add(Duration(minutes: 5)))],
        onLists: [lists[1]]
    ));
    items.add(TodoItem("third item", now.add(Duration(hours: 5)),
      note: "a longer\nnote for the third item\ninthislist",
      dueDate: now.add(Duration(days: 10)), priority: TodoPriority.low,
      onLists: [lists[1],lists[2]]
    ));
    items.add(TodoItem("fourth item", now.add(Duration(days: 80)),
      priority: TodoPriority.medium, reminders: [Reminder(now.add(Duration(days: 25)))],
      onLists: lists
    ));
    for (int i=0; i<items.length; i++) {
      var item = items[i];
      var added = await repository.addTodoItem(item);
      item = item.copyWith(id: added.id);
      if (item.reminders != null && item.reminders.isNotEmpty) {
        for (int j=0; j<item.reminders.length; j++) {
          var reminder = item.reminders[j];
          reminder = reminder.withId(added.reminders[j].id);
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

  test('add item onList', () async {
    var list = TodoList("Main list", Palette.grey);
    var listId = await repository.addTodoList(list);
    list = list.withId(listId);
    var item = TodoItem(
      "Item title", DateTime.now()
    );
    var added = await repository.addTodoItem(item, onList: list);
    expect(added, item.copyWith(id: added.id, onLists: [list]));
    var saved = await repository.getTodoItem(added.id);
    expect(saved, added);
  });

  test('add item onLists', () async {
    var item = TodoItem(
        "Item title", DateTime.now(), onLists: lists
    );
    var added = await repository.addTodoItem(item);
    expect(added, item.copyWith(id: added.id));
    var saved = await repository.getTodoItem(added.id);
    expect(saved, added);
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
    // Reminders and lists are not affected by the update
    expect(await repository.getTodoItem(updateId), updateItem.copyWith(reminders: items[1].reminders, onLists: items[1].onLists));
  });


  test('update short item test', () async {
    var updateId = items[1].id;
    var updateItem = TodoItem("updated", DateTime.now(), id: updateId);
    await repository.updateTodoItem(updateItem.shorten());
    for (final item in items.where((element) => element.id != updateId)) {
      var resultItem = await repository.getTodoItem(item.id);
      expect(resultItem, item);
    }
    // Reminders and lists are not affected by the update
    expect(await repository.getTodoItem(updateId), updateItem.copyWith(reminders: items[1].reminders, onLists: items[1].onLists));
  });
}