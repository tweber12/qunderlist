import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/sqflite/todo_list.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Init ffi loader if needed.
  sqfliteFfiInit();
  test('persist list test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);
    TodoList list = TodoList("test name", Palette.green);
    var id = await listDao.addTodoList(list);
    TodoList resultList = await listDao.getTodoList(id);
    expect(resultList, list.withId(id));
    await db.close();
  });

  test('update list test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    TodoList listU = TodoList("test name update", Palette.yellow, id: id2);
    await listDao.updateTodoList(listU);
    TodoList resultList1 = await listDao.getTodoList(id1);
    expect(resultList1, list1.withId(id1));
    TodoList resultList2 = await listDao.getTodoList(id2);
    expect(resultList2, listU);
    TodoList resultList3 = await listDao.getTodoList(id3);
    expect(resultList3, list3.withId(id3));
    await db.close();
  });

  test('delete list test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    await listDao.deleteTodoList(id2);
    TodoList resultList1 = await listDao.getTodoList(id1);
    expect(resultList1, list1.withId(id1));
    TodoList resultList2 = await listDao.getTodoList(id2);
    expect(resultList2, null);
    TodoList resultList3 = await listDao.getTodoList(id3);
    expect(resultList3, list3.withId(id3));
    await db.close();
  });


  test('get list by name test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    TodoList resultList1 = await listDao.getTodoListByName(list1.listName);
    expect(resultList1, list1.withId(id1));
    TodoList resultList3 = await listDao.getTodoListByName(list3.listName);
    expect(resultList3, list3.withId(id3));
    TodoList resultList2 = await listDao.getTodoListByName(list2.listName);
    expect(resultList2, list2.withId(id2));
    await db.close();
  });

  test('get number of lists test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    expect(await listDao.getNumberOfTodoLists(), 0);
    var id1 = await listDao.addTodoList(list1);
    expect(await listDao.getNumberOfTodoLists(), 1);
    var id2 = await listDao.addTodoList(list2);
    expect(await listDao.getNumberOfTodoLists(), 2);
    var id3 = await listDao.addTodoList(list3);
    expect(await listDao.getNumberOfTodoLists(), 3);
    await listDao.deleteTodoList(id1);
    expect(await listDao.getNumberOfTodoLists(), 2);
    await listDao.deleteTodoList(id3);
    expect(await listDao.getNumberOfTodoLists(), 1);
    await listDao.deleteTodoList(id2);
    expect(await listDao.getNumberOfTodoLists(), 0);
    await db.close();
  });

  test('get list chunk full test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var lists = await listDao.getTodoListsChunk(0, 3);
    expect(lists.length, 3);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list2.withId(id2));
    expect(lists[2], list3.withId(id3));
    await db.close();
  });

  test('get list chunk pieces test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var lists = await listDao.getTodoListsChunk(1, 2);
    expect(lists.length, 1);
    expect(lists[0], list2.withId(id2));
    lists = await listDao.getTodoListsChunk(2, 3);
    expect(lists.length, 1);
    expect(lists[0], list3.withId(id3));
    lists = await listDao.getTodoListsChunk(0, 1);
    expect(lists.length, 1);
    expect(lists[0], list1.withId(id1));
    await db.close();
  });

  test('get list matching full test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var lists = await listDao.getMatchingLists("", 3);
    expect(lists.length, 3);
    expect(lists[0], list3.withId(id3));
    expect(lists[1], list2.withId(id2));
    expect(lists[2], list1.withId(id1));
    await db.close();
  });

  test('get list matching full limited test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var lists = await listDao.getMatchingLists("", 2);
    expect(lists.length, 2);
    expect(lists[0], list3.withId(id3));
    expect(lists[1], list2.withId(id2));
    await db.close();
  });

  test('get list matching start test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var lists = await listDao.getMatchingLists("test", 3);
    expect(lists.length, 2);
    expect(lists[0], list2.withId(id2));
    expect(lists[1], list1.withId(id1));
    await db.close();
  });

  test('get list matching pattern middle test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var lists = await listDao.getMatchingLists("st g", 3);
    expect(lists.length, 1);
    expect(lists[0], list2.withId(id2));
    await db.close();
  });


  test('get list matching end test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var lists = await listDao.getMatchingLists(" 2", 3);
    expect(lists.length, 1);
    expect(lists[0], list2.withId(id2));
    await db.close();
  });

  test('get reorder list mid up test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var id4 = await listDao.addTodoList(list4);
    var id5 = await listDao.addTodoList(list5);

    await listDao.moveTodoList(id4, 2);

    expect(await listDao.getNumberOfTodoLists(), 5);
    var lists = await listDao.getTodoListsChunk(0, 5);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list4.withId(id4));
    expect(lists[2], list2.withId(id2));
    expect(lists[3], list3.withId(id3));
    expect(lists[4], list5.withId(id5));
    await db.close();
  });

  test('get reorder list mid down test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var id4 = await listDao.addTodoList(list4);
    var id5 = await listDao.addTodoList(list5);

    await listDao.moveTodoList(id2, 4);

    expect(await listDao.getNumberOfTodoLists(), 5);
    var lists = await listDao.getTodoListsChunk(0, 5);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list3.withId(id3));
    expect(lists[2], list4.withId(id4));
    expect(lists[3], list2.withId(id2));
    expect(lists[4], list5.withId(id5));
    await db.close();
  });

  test('get reorder list mid down bottom test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var id4 = await listDao.addTodoList(list4);
    var id5 = await listDao.addTodoList(list5);

    await listDao.moveTodoList(id2, 5);

    expect(await listDao.getNumberOfTodoLists(), 5);
    var lists = await listDao.getTodoListsChunk(0, 5);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list3.withId(id3));
    expect(lists[2], list4.withId(id4));
    expect(lists[3], list5.withId(id5));
    expect(lists[4], list2.withId(id2));
    await db.close();
  });

  test('get reorder list mid up top test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var id4 = await listDao.addTodoList(list4);
    var id5 = await listDao.addTodoList(list5);

    await listDao.moveTodoList(id3, 1);

    expect(await listDao.getNumberOfTodoLists(), 5);
    var lists = await listDao.getTodoListsChunk(0, 5);
    expect(lists[0], list3.withId(id3));
    expect(lists[1], list1.withId(id1));
    expect(lists[2], list2.withId(id2));
    expect(lists[3], list4.withId(id4));
    expect(lists[4], list5.withId(id5));
    await db.close();
  });

  test('get reorder list bottom up test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var id4 = await listDao.addTodoList(list4);
    var id5 = await listDao.addTodoList(list5);

    await listDao.moveTodoList(id5, 4);

    expect(await listDao.getNumberOfTodoLists(), 5);
    var lists = await listDao.getTodoListsChunk(0, 5);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list2.withId(id2));
    expect(lists[2], list3.withId(id3));
    expect(lists[3], list5.withId(id5));
    expect(lists[4], list4.withId(id4));
    await db.close();
  });

  test('get reorder list bottom up top test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var id4 = await listDao.addTodoList(list4);
    var id5 = await listDao.addTodoList(list5);

    await listDao.moveTodoList(id5, 1);

    expect(await listDao.getNumberOfTodoLists(), 5);
    var lists = await listDao.getTodoListsChunk(0, 5);
    expect(lists[0], list5.withId(id5));
    expect(lists[1], list1.withId(id1));
    expect(lists[2], list2.withId(id2));
    expect(lists[3], list3.withId(id3));
    expect(lists[4], list4.withId(id4));
    await db.close();
  });

  test('get reorder list top down test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var id4 = await listDao.addTodoList(list4);
    var id5 = await listDao.addTodoList(list5);

    await listDao.moveTodoList(id1, 2);

    expect(await listDao.getNumberOfTodoLists(), 5);
    var lists = await listDao.getTodoListsChunk(0, 5);
    expect(lists[0], list2.withId(id2));
    expect(lists[1], list1.withId(id1));
    expect(lists[2], list3.withId(id3));
    expect(lists[3], list4.withId(id4));
    expect(lists[4], list5.withId(id5));
    await db.close();
  });

  test('get reorder list top down bottom test', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    TodoListDao listDao = await TodoListDao.getInstance(db);

    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await listDao.addTodoList(list1);
    var id2 = await listDao.addTodoList(list2);
    var id3 = await listDao.addTodoList(list3);
    var id4 = await listDao.addTodoList(list4);
    var id5 = await listDao.addTodoList(list5);

    await listDao.moveTodoList(id1, 5);

    expect(await listDao.getNumberOfTodoLists(), 5);
    var lists = await listDao.getTodoListsChunk(0, 5);
    expect(lists[0], list2.withId(id2));
    expect(lists[1], list3.withId(id3));
    expect(lists[2], list4.withId(id4));
    expect(lists[3], list5.withId(id5));
    expect(lists[4], list1.withId(id1));
    await db.close();
  });
}