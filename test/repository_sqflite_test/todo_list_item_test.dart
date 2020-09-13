import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/sqflite/reminder.dart';
import 'package:qunderlist/repository/sqflite/todo_item.dart';
import 'package:qunderlist/repository/sqflite/todo_list.dart';
import 'package:qunderlist/repository/sqflite/todo_list_item.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Init ffi loader if needed.
  sqfliteFfiInit();
  group("unordered", () {
    Database db;
    TodoListDao listDao;
    TodoListItemDao dao;
    List<TodoList> lists;
    List<List<TodoItem>> items;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, onCreate: createDatabase, onConfigure: configureDatabase));
      dao = await TodoListItemDao.getInstance(db);
      listDao = await TodoListDao.getInstance(db);
      var itemDao = TodoItemDao(db);
      var reminderDao = ReminderDao(db);

      // Set up two lists
      lists = [
        TodoList("first list", Palette.blue),
        TodoList("second list", Palette.yellow)
      ];
      for (int i=0; i<lists.length; i++) {
        var id = await listDao.addTodoList(lists[i]);
        lists[i] = lists[i].withId(id);
      }

      // Add items to the first list
      items = List();
      var items1 = List<TodoItem>();
      var now = DateTime.now();
      items1.add(TodoItem("first item", now));
      items1.add(TodoItem("second item", now.add(Duration(hours: 1)),
          note: "note for second item", completed: true, completedOn: now.subtract(Duration(minutes: 1)),
          dueDate: now.add(Duration(days: 1)), priority: TodoPriority.high, reminders: [Reminder(now), Reminder(now.add(Duration(minutes: 5)))]
      ));
      items1.add(TodoItem("third item", now.add(Duration(hours: 5)),
        note: "a longer\nnote for the third item\ninthislist", completed: false,
        dueDate: now.add(Duration(days: 10)), priority: TodoPriority.low,
      ));
      items1.add(TodoItem("fourth item", now.add(Duration(days: 80)),
          priority: TodoPriority.medium, reminders: [Reminder(now.add(Duration(days: 25)))]
      ));
      items.add(items1);

      // Add items to the second list
      var items2 = List<TodoItem>();
      now = DateTime.now();
      items2.add(TodoItem("first item, second list", now));
      items2.add(TodoItem("second list, second item", now.add(Duration(hours: 5)),
        note: "a longer\nnote for this item\ninthesecondlist", completed: false,
        dueDate: now.add(Duration(days: 10)), priority: TodoPriority.low,
      ));
      items2.add(TodoItem("third item, second list", now.add(Duration(hours: 1)),
          note: "note for the third item on the second list", completed: true, completedOn: now.subtract(Duration(minutes: 1)),
          dueDate: now.add(Duration(days: 1)), priority: TodoPriority.high, reminders: [Reminder(now), Reminder(now.add(Duration(minutes: 5)))]
      ));
      items2.add(TodoItem("finally the fourth and last item", now.add(Duration(days: 80)),
          priority: TodoPriority.medium, reminders: [Reminder(now.add(Duration(days: 25)))]
      ));
      items2.add(TodoItem("... or is it", now.add(Duration(days: 80)), note: "sneakily add another one\n\njust\nin\ncase",
          priority: TodoPriority.none
      ));
      items.add(items2);

      // Actually add the items and respective reminders
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        for (int i = 0; i < items[listIndex].length; i++) {
          var item = items[listIndex][i];
          var id = await itemDao.addTodoItem(item);
          dao.addItemToList(id, lists[listIndex].id);
          item = item.copyWith(id: id);
          if (item.reminders != null && item.reminders.isNotEmpty) {
            for (int j = 0; j < item.reminders.length; j++) {
              var reminder = item.reminders[j];
              var id = await reminderDao.addReminder(item.id, reminder.at);
              reminder = reminder.withId(id);
              item.reminders[j] = reminder;
            }
          }
          items[listIndex][i] = item;
        }
      }
    });
    tearDown(() async {
      lists = null;
      items = null;
      listDao = null;
      dao = null;
      db.close();
    });

    test("get all", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var resultItems = await dao.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.all);
        for (final item in items[listIndex]) {
          expect(resultItems.contains(item), true);
        }
        expect(resultItems.length, items[listIndex].length);
      }
    });

    test("get active", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var resultItems = await dao.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.active);
        var active = 0;
        for (final item in items[listIndex]) {
          if (item.completed) {
            expect(resultItems.contains(item), false);
          } else {
            expect(resultItems.contains(item), true);
            active+=1;
          }
        }
        expect(resultItems.length, active);
      }
    });

    test("get completed", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var resultItems = await dao.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.completed);
        var active = 0;
        for (final item in items[listIndex]) {
          if (!item.completed) {
            expect(resultItems.contains(item), false);
          } else {
            expect(resultItems.contains(item), true);
            active+=1;
          }
        }
        expect(resultItems.length, active);
      }
    });

    test("get important", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var resultItems = await dao.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.important);
        var active = 0;
        for (final item in items[listIndex]) {
          if (item.completed || item.priority == TodoPriority.none) {
            expect(resultItems.contains(item), false);
          } else {
            expect(resultItems.contains(item), true);
            active+=1;
          }
        }
        expect(resultItems.length, active);
      }
    });

    test("get with due date", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var resultItems = await dao.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.withDueDate);
        var active = 0;
        for (final item in items[listIndex]) {
          if (item.completed || item.dueDate == null) {
            expect(resultItems.contains(item), false);
          } else {
            expect(resultItems.contains(item), true);
            active+=1;
          }
        }
        expect(resultItems.length, active);
      }
    });

    test("get number all", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        expect(await dao.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.all), items[listIndex].length);
      }
    });

    test("get number active", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var active = 0;
        for (final item in items[listIndex]) {
          if (!item.completed) {
            active+=1;
          }
        }
        expect(await dao.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.active), active);
      }
    });

    test("get number completed", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var active = 0;
        for (final item in items[listIndex]) {
          if (item.completed) {
            active+=1;
          }
        }
        expect(await dao.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.completed), active);
      }
    });

    test("get number important", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var active = 0;
        for (final item in items[listIndex]) {
          if (!item.completed && item.priority!=TodoPriority.none) {
            active+=1;
          }
        }
        expect(await dao.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.important), active);
      }
    });

    test("get number with due date", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var active = 0;
        for (final item in items[listIndex]) {
          if (!item.completed && item.dueDate!=null) {
            active+=1;
          }
        }
        expect(await dao.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.withDueDate), active);
      }
    });

    test("add item to list", () async {
      var item = items[0][1];
      await dao.addItemToList(item.id, lists[1].id);
      var i1 = await dao.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), true);
      var i2 = await dao.getTodoItemsOfListChunk(lists[1].id, 0, 10, TodoStatusFilter.all);
      expect(i2.contains(item), true);
    });

    test("remove item from list multi", () async {
      var item = items[0][1];
      await dao.addItemToList(item.id, lists[1].id);
      var i1 = await dao.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), true);
      var i2 = await dao.getTodoItemsOfListChunk(lists[1].id, 0, 10, TodoStatusFilter.all);
      expect(i2.contains(item), true);
      await dao.removeTodoItemFromList(item.id, lists[0].id);
      i1 = await dao.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), false);
    });

    test("remove item from list", () async {
      var item = items[0][1];
      await dao.removeTodoItemFromList(item.id, lists[0].id);
      var i1 = await dao.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), false);
      var resultItem = await TodoItemDao(db).getTodoItem(item.id);
      expect(resultItem, null);
    });

    test("cascade list delete", () async {
      var item = items[0][1];
      await dao.addItemToList(item.id, lists[1].id);
      await listDao.deleteTodoList(lists[0].id);
      // The connection between list and items was removed
      var i1 = await dao.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.isEmpty, true);
      // The item that is contained in another list is untouched
      var resultItem = await TodoItemDao(db).getTodoItem(item.id);
      expect(resultItem, item);
      // All other items have been removed
      for (final i in items[0]) {
        if (i.id != item.id) {
          var resultItem = await TodoItemDao(db).getTodoItem(i.id);
          expect(resultItem, null);
        }
      }
    });

    test("move item to list", () async {
      var item = items[0][2];
      await dao.moveTodoItemToList(item.id, lists[0].id, lists[1].id);
      var i2 = await dao.getTodoItemsOfListChunk(lists[1].id, 0, 10, TodoStatusFilter.all);
      expect(i2.contains(item), true);
      var i1 = await dao.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), false);
    });

    test("get lists of item", () async {
      var item = items[1][0];
      var l1 = await dao.getListsOfItem(item.id);
      expect(l1, [lists[1]]);
      await dao.addItemToList(item.id, lists[0].id);
      var l2 = await dao.getListsOfItem(item.id);
      expect(l2, lists);
      await dao.removeTodoItemFromList(item.id, lists[1].id);
      var l3 = await dao.getListsOfItem(item.id);
      expect(l3, [lists[0]]);
    });
  });

  group("ordered", ()
  {
    Database db;
    TodoListItemDao dao;
    int listId;
    List<TodoItem> items;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1,
              onCreate: createDatabase,
              onConfigure: configureDatabase));
      dao = await TodoListItemDao.getInstance(db);
      var listDao = await TodoListDao.getInstance(db);
      var itemDao = TodoItemDao(db);

      listId = await listDao.addTodoList(TodoList("test", Palette.yellow));

      // Add items to the first list
      items = List();
      var now = DateTime.now();
      items.add(TodoItem("first item", now, completedOn: now.add(Duration(hours: 5))));
      items.add(TodoItem("first item", now, priority: TodoPriority.low, dueDate: now.add(Duration(hours: 5))));
      items.add(TodoItem("second item", now, completedOn: now.add(Duration(hours: 4))));
      items.add(TodoItem("second item", now, priority: TodoPriority.high, dueDate: now.add(Duration(hours: 4))));
      items.add(TodoItem("third item", now, priority: TodoPriority.none, dueDate: now.add(Duration(hours: 2))));
      items.add(TodoItem("third item", now, completedOn: now.add(Duration(hours: 2))));
      items.add(TodoItem("fourth item", now, completedOn: now.add(Duration(hours: 18))));
      items.add(TodoItem("fourth item", now, priority: TodoPriority.medium, dueDate: now.add(Duration(hours: 18))));
      items.add(TodoItem("fifth item", now, priority: TodoPriority.high, dueDate: now.add(Duration(hours: 29))));
      items.add(TodoItem("fifth item", now, completedOn: now.add(Duration(hours: 29))));
      items.add(TodoItem("sixth item", now, priority: TodoPriority.low, dueDate: now.add(Duration(hours: 1))));
      items.add(TodoItem("sixth item", now, completedOn: now.add(Duration(hours: 1))));

      // Actually add the items and respective reminders
      for (int i = 0; i < items.length; i++) {
        var item = items[i];
        var id = await itemDao.addTodoItem(item);
        dao.addItemToList(id, listId);
        item = item.copyWith(id: id);
        items[i] = item;
      }
    });
    tearDown(() async {
      items = null;
      dao = null;
      db.close();
    });

    test("get items active", () async {
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      var expected = items.where((element) => element.completedOn==null).toList();
      expect(resultItems.length, expected.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], expected[i]);
      }
    });

    test("get items completed", () async {
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.completed);
      var expected = items.where((element) => element.completedOn!=null).toList();
      expected.sort((a,b) => b.completedOn.compareTo(a.completedOn));
      expect(resultItems.length, expected.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], expected[i]);
      }
    });

    test("get items important", () async {
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.important);
      var expected = items.where((element) => element.completedOn==null && element.priority!=TodoPriority.none).toList();
      expect(resultItems.length, expected.length);
      expected.sort((a,b) => a.priority.index.compareTo(b.priority.index));
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], expected[i]);
      }
    });

    test("get items with due date", () async {
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.withDueDate);
      var expected = items.where((element) => element.completedOn==null && element.dueDate!=null).toList();
      expect(resultItems.length, expected.length);
      expected.sort((a,b) => a.dueDate.compareTo(b.dueDate));
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], expected[i]);
      }
    });

    test("move item mid up", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[4];
      var itemTo = active[2];
      await dao.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(2, itemFrom);
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item mid down", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[1];
      var itemTo = active[4];
      await dao.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(4, itemFrom);
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item mid up top", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[4];
      var itemTo = active[0];
      await dao.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(0, itemFrom);
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item mid down bottom", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[3];
      var itemTo = active.last;
      await dao.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.add(itemFrom);
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item bottom up", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active.last;
      var itemTo = active[3];
      await dao.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(3, itemFrom);
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item top down", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[0];
      var itemTo = active[3];
      await dao.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(3, itemFrom);
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item bottom up top", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active.last;
      var itemTo = active[0];
      await dao.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(0, itemFrom);
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item top down bottom", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[0];
      var itemTo = active.last;
      await dao.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.add(itemFrom);
      var resultItems = await dao.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });
  });
}