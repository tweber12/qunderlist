import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/sqflite/todo_item.dart';
import 'package:qunderlist/repository/sqflite/todo_list.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Init ffi loader if needed.
  sqfliteFfiInit();
  group("unordered", () {
    Database db;
    TodoRepositorySqflite repository;
    List<TodoList> lists;
    List<List<TodoItemShort>> items;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, onCreate: createDatabase, onConfigure: configureDatabase));
      repository = await TodoRepositorySqflite.getInstance(db: db);

      // Set up two lists
      lists = [
        TodoList("first list", Palette.blue),
        TodoList("second list", Palette.yellow)
      ];
      for (int i=0; i<lists.length; i++) {
        var id = await repository.addTodoList(lists[i]);
        lists[i] = lists[i].withId(id);
      }

      // Add items to the first list
      items = List();
      var fullItems = List();
      var items1 = List<TodoItem>();
      var now = DateTime.now();
      items1.add(TodoItem("first item", now));
      items1.add(TodoItem("second item", now.add(Duration(hours: 1)),
          note: "note for second item", completedOn: now.subtract(Duration(minutes: 1)),
          dueDate: now.add(Duration(days: 1)), priority: TodoPriority.high, reminders: [Reminder(now), Reminder(now.add(Duration(minutes: 5)))],
          repeated: Repeated(true, false, true, false, RepeatedStepYearly(1, 8, 31))
      ));
      items1.add(TodoItem("third item", now.add(Duration(hours: 5)),
        note: "a longer\nnote for the third item\ninthislist",
        dueDate: now.add(Duration(days: 10)), priority: TodoPriority.low,
        repeated: Repeated(false, true, true, false, RepeatedStepDaily(3))
      ));
      items1.add(TodoItem("fourth item", now.add(Duration(days: 80)),
          priority: TodoPriority.medium, reminders: [Reminder(now.add(Duration(days: 25)))]
      ));
      fullItems.add(items1);

      // Add items to the second list
      var items2 = List<TodoItem>();
      now = DateTime.now();
      items2.add(TodoItem("first item, second list", now));
      items2.add(TodoItem("second list, second item", now.add(Duration(hours: 5)),
        note: "a longer\nnote for this item\ninthesecondlist",
        dueDate: now.add(Duration(days: 10)), priority: TodoPriority.low,
        repeated: Repeated(true, false, false, true, RepeatedStepMonthly(9, 1))
      ));
      items2.add(TodoItem("third item, second list", now.add(Duration(hours: 1)),
          note: "note for the third item on the second list", completedOn: now.subtract(Duration(minutes: 1)),
          dueDate: now.add(Duration(days: 1)), priority: TodoPriority.high, reminders: [Reminder(now), Reminder(now.add(Duration(minutes: 5)))]
      ));
      items2.add(TodoItem("finally the fourth and last item", now.add(Duration(days: 80)),
          priority: TodoPriority.medium, reminders: [Reminder(now.add(Duration(days: 25)))]
      ));
      items2.add(TodoItem("... or is it", now.add(Duration(days: 80)), note: "sneakily add another one\n\njust\nin\ncase",
          priority: TodoPriority.none,
          repeated: Repeated(false, true, false, false, RepeatedStepWeekly(2))
      ));
      fullItems.add(items2);

      // Actually add the items and respective reminders
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        items.add(List());
        for (int i = 0; i < fullItems[listIndex].length; i++) {
          var item = fullItems[listIndex][i];
          item = await repository.addTodoItem(item, onList: lists[listIndex]);
          items[listIndex].add(item.shorten());
        }
      }
    });
    tearDown(() async {
      lists = null;
      items = null;
      db.close();
    });

    test("get all", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var resultItems = await repository.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.all);
        for (final item in items[listIndex]) {
          expect(resultItems.contains(item), true);
        }
        expect(resultItems.length, items[listIndex].length);
      }
    });

    test("get active", () async {
      for (int listIndex=0; listIndex<lists.length; listIndex++) {
        var resultItems = await repository.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.active);
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
        var resultItems = await repository.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.completed);
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
        var resultItems = await repository.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.important);
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
        var resultItems = await repository.getTodoItemsOfListChunk(lists[listIndex].id, 0, 10, TodoStatusFilter.withDueDate);
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
        expect(await repository.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.all), items[listIndex].length);
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
        expect(await repository.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.active), active);
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
        expect(await repository.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.completed), active);
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
        expect(await repository.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.important), active);
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
        expect(await repository.getNumberOfTodoItems(lists[listIndex].id, TodoStatusFilter.withDueDate), active);
      }
    });

    test("add item to list", () async {
      var item = items[0][1];
      await repository.addTodoItemToList(item.id, lists[1].id);
      var i1 = await repository.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), true);
      var i2 = await repository.getTodoItemsOfListChunk(lists[1].id, 0, 10, TodoStatusFilter.all);
      expect(i2.contains(item), true);
    });

    test("remove item from list multi", () async {
      var item = items[0][1];
      await repository.addTodoItemToList(item.id, lists[1].id);
      var i1 = await repository.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), true);
      var i2 = await repository.getTodoItemsOfListChunk(lists[1].id, 0, 10, TodoStatusFilter.all);
      expect(i2.contains(item), true);
      await repository.removeTodoItemFromList(item.id, lists[0].id);
      i1 = await repository.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), false);
    });

    test("remove item from list", () async {
      var item = items[0][1];
      await repository.removeTodoItemFromList(item.id, lists[0].id);
      var i1 = await repository.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), false);
      var resultItem = await TodoItemDao(db).getTodoItem(item.id);
      expect(resultItem, null);
    });

    test("cascade list delete", () async {
      var item = items[0][1];
      await repository.addTodoItemToList(item.id, lists[1].id);
      await repository.deleteTodoList(lists[0].id);
      // The connection between list and items was removed
      var i1 = await repository.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.isEmpty, true);
      // The item that is contained in another list is untouched
      var resultItem = await TodoItemDao(db).getTodoItem(item.id);
      expect(resultItem.shorten(), item);
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
      await repository.moveTodoItemToList(item.id, lists[0].id, lists[1].id);
      var i2 = await repository.getTodoItemsOfListChunk(lists[1].id, 0, 10, TodoStatusFilter.all);
      expect(i2.contains(item), true);
      var i1 = await repository.getTodoItemsOfListChunk(lists[0].id, 0, 10, TodoStatusFilter.all);
      expect(i1.contains(item), false);
    });

    test("get lists of item", () async {
      var item = items[1][0];
      var l1 = await repository.getListsOfItem(item.id);
      expect(l1, [lists[1]]);
      await repository.addTodoItemToList(item.id, lists[0].id);
      var l2 = await repository.getListsOfItem(item.id);
      expect(l2, lists);
      await repository.removeTodoItemFromList(item.id, lists[1].id);
      var l3 = await repository.getListsOfItem(item.id);
      expect(l3, [lists[0]]);
    });
  });

  group("ordered", ()
  {
    Database db;
    TodoRepositorySqflite repository;
    int listId;
    List<TodoItemShort> items;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1,
              onCreate: createDatabase,
              onConfigure: configureDatabase));
      repository = await TodoRepositorySqflite.getInstance(db: db);
      var listDao = await TodoListDao.getInstance(db);
      var itemDao = TodoItemDao(db);

      listId = await listDao.addTodoList(TodoList("test", Palette.yellow));

      // Add items to the first list
      items = List();
      var fullItems = List();
      var now = DateTime.now();
      fullItems.add(TodoItem("first item", now, completedOn: now.add(Duration(hours: 5))));
      fullItems.add(TodoItem("first item", now, priority: TodoPriority.low, dueDate: now.add(Duration(hours: 5))));
      fullItems.add(TodoItem("second item", now, completedOn: now.add(Duration(hours: 4))));
      fullItems.add(TodoItem("second item", now, priority: TodoPriority.high, dueDate: now.add(Duration(hours: 4))));
      fullItems.add(TodoItem("third item", now, priority: TodoPriority.none, dueDate: now.add(Duration(hours: 2))));
      fullItems.add(TodoItem("third item", now, completedOn: now.add(Duration(hours: 2))));
      fullItems.add(TodoItem("fourth item", now, completedOn: now.add(Duration(hours: 18))));
      fullItems.add(TodoItem("fourth item", now, priority: TodoPriority.medium, dueDate: now.add(Duration(hours: 18))));
      fullItems.add(TodoItem("fifth item", now, priority: TodoPriority.high, dueDate: now.add(Duration(hours: 29))));
      fullItems.add(TodoItem("fifth item", now, completedOn: now.add(Duration(hours: 29))));
      fullItems.add(TodoItem("sixth item", now, priority: TodoPriority.low, dueDate: now.add(Duration(hours: 1))));
      fullItems.add(TodoItem("sixth item", now, completedOn: now.add(Duration(hours: 1))));

      // Actually add the items and respective reminders
      for (int i = 0; i < fullItems.length; i++) {
        var item = fullItems[i];
        var id = await itemDao.addTodoItem(item);
        repository.addTodoItemToList(id, listId);
        item = item.copyWith(id: id);
        items.add(item.shorten());
      }
    });
    tearDown(() async {
      items = null;
      repository = null;
      db.close();
    });

    test("get items active", () async {
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      var expected = items.where((element) => element.completedOn==null).toList();
      expect(resultItems.length, expected.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], expected[i]);
      }
    });

    test("get items completed", () async {
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.completed);
      var expected = items.where((element) => element.completedOn!=null).toList();
      expected.sort((a,b) => b.completedOn.compareTo(a.completedOn));
      expect(resultItems.length, expected.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], expected[i]);
      }
    });

    test("get items important", () async {
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.important);
      var expected = items.where((element) => element.completedOn==null && element.priority!=TodoPriority.none).toList();
      expect(resultItems.length, expected.length);
      expected.sort((a,b) => a.priority.index.compareTo(b.priority.index));
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], expected[i]);
      }
    });

    test("get items with due date", () async {
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.withDueDate);
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
      await repository.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(2, itemFrom);
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item mid down", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[1];
      var itemTo = active[4];
      await repository.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(4, itemFrom);
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item mid up top", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[4];
      var itemTo = active[0];
      await repository.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(0, itemFrom);
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item mid down bottom", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[3];
      var itemTo = active.last;
      await repository.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.add(itemFrom);
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item bottom up", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active.last;
      var itemTo = active[3];
      await repository.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(3, itemFrom);
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item top down", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[0];
      var itemTo = active[3];
      await repository.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(3, itemFrom);
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item bottom up top", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active.last;
      var itemTo = active[0];
      await repository.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.insert(0, itemFrom);
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });

    test("move item top down bottom", () async {
      var active = items.where((element) => element.completedOn==null).toList();
      var itemFrom = active[0];
      var itemTo = active.last;
      await repository.moveTodoItemInList(itemFrom.id, listId, itemTo.id);
      active.remove(itemFrom);
      active.add(itemFrom);
      var resultItems = await repository.getTodoItemsOfListChunk(listId, 0, 10, TodoStatusFilter.active);
      expect(resultItems.length, active.length);
      for (int i=0; i<resultItems.length; i++) {
        expect(resultItems[i], active[i]);
      }
    });
  });
}