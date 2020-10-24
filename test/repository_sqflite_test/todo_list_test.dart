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

import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Init ffi loader if needed.
  sqfliteFfiInit();
  Database db;
  TodoRepositorySqflite repository;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: createDatabase));
    repository = await TodoRepositorySqflite.getInstance(db: db);
  });
  tearDown(() async {
    repository = null;
    await db.close();
  });
  test('persist list test', () async {
    TodoList list = TodoList("test name", Palette.green);
    var id = await repository.addTodoList(list);
    TodoList resultList = await repository.getTodoList(id);
    expect(resultList, list.withId(id));
  });

  test('update list test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    TodoList listU = TodoList("test name update", Palette.yellow, id: id2);
    await repository.updateTodoList(listU);
    TodoList resultList1 = await repository.getTodoList(id1);
    expect(resultList1, list1.withId(id1));
    TodoList resultList2 = await repository.getTodoList(id2);
    expect(resultList2, listU);
    TodoList resultList3 = await repository.getTodoList(id3);
    expect(resultList3, list3.withId(id3));
  });

  test('delete list test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    await repository.deleteTodoList(id2);
    TodoList resultList1 = await repository.getTodoList(id1);
    expect(resultList1, list1.withId(id1));
    TodoList resultList2 = await repository.getTodoList(id2);
    expect(resultList2, null);
    TodoList resultList3 = await repository.getTodoList(id3);
    expect(resultList3, list3.withId(id3));
  });


  test('get list by name test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    TodoList resultList1 = await repository.getTodoListByName(list1.listName);
    expect(resultList1, list1.withId(id1));
    TodoList resultList3 = await repository.getTodoListByName(list3.listName);
    expect(resultList3, list3.withId(id3));
    TodoList resultList2 = await repository.getTodoListByName(list2.listName);
    expect(resultList2, list2.withId(id2));
  });

  test('get number of lists test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    expect(await repository.getNumberOfTodoLists(), 0);
    var id1 = await repository.addTodoList(list1);
    expect(await repository.getNumberOfTodoLists(), 1);
    var id2 = await repository.addTodoList(list2);
    expect(await repository.getNumberOfTodoLists(), 2);
    var id3 = await repository.addTodoList(list3);
    expect(await repository.getNumberOfTodoLists(), 3);
    await repository.deleteTodoList(id1);
    expect(await repository.getNumberOfTodoLists(), 2);
    await repository.deleteTodoList(id3);
    expect(await repository.getNumberOfTodoLists(), 1);
    await repository.deleteTodoList(id2);
    expect(await repository.getNumberOfTodoLists(), 0);
  });

  test('get list chunk full test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var lists = await repository.getTodoListsChunk(0, 3);
    expect(lists.length, 3);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list2.withId(id2));
    expect(lists[2], list3.withId(id3));
  });

  test('get list chunk pieces test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var lists = await repository.getTodoListsChunk(1, 2);
    expect(lists.length, 1);
    expect(lists[0], list2.withId(id2));
    lists = await repository.getTodoListsChunk(2, 3);
    expect(lists.length, 1);
    expect(lists[0], list3.withId(id3));
    lists = await repository.getTodoListsChunk(0, 1);
    expect(lists.length, 1);
    expect(lists[0], list1.withId(id1));
  });

  test('get list matching full test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var lists = await repository.getMatchingLists("", limit: 3);
    expect(lists.length, 3);
    expect(lists[0], list3.withId(id3));
    expect(lists[1], list2.withId(id2));
    expect(lists[2], list1.withId(id1));
  });

  test('get list matching full limited test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var lists = await repository.getMatchingLists("", limit: 2);
    expect(lists.length, 2);
    expect(lists[0], list3.withId(id3));
    expect(lists[1], list2.withId(id2));
  });

  test('get list matching start test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var lists = await repository.getMatchingLists("test", limit: 3);
    expect(lists.length, 2);
    expect(lists[0], list2.withId(id2));
    expect(lists[1], list1.withId(id1));
  });

  test('get list matching pattern middle test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var lists = await repository.getMatchingLists("st g", limit: 3);
    expect(lists.length, 1);
    expect(lists[0], list2.withId(id2));
  });


  test('get list matching end test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test game 2", Palette.pink);
    TodoList list3 = TodoList("guest name 3", Palette.blue);
    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var lists = await repository.getMatchingLists(" 2", limit: 3);
    expect(lists.length, 1);
    expect(lists[0], list2.withId(id2));
  });

  test('get reorder list mid up test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var id4 = await repository.addTodoList(list4);
    var id5 = await repository.addTodoList(list5);

    await repository.moveTodoList(id4, 2);

    expect(await repository.getNumberOfTodoLists(), 5);
    var lists = await repository.getTodoListsChunk(0, 5);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list4.withId(id4));
    expect(lists[2], list2.withId(id2));
    expect(lists[3], list3.withId(id3));
    expect(lists[4], list5.withId(id5));
  });

  test('get reorder list mid down test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var id4 = await repository.addTodoList(list4);
    var id5 = await repository.addTodoList(list5);

    await repository.moveTodoList(id2, 4);

    expect(await repository.getNumberOfTodoLists(), 5);
    var lists = await repository.getTodoListsChunk(0, 5);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list3.withId(id3));
    expect(lists[2], list4.withId(id4));
    expect(lists[3], list2.withId(id2));
    expect(lists[4], list5.withId(id5));
  });

  test('get reorder list mid down bottom test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var id4 = await repository.addTodoList(list4);
    var id5 = await repository.addTodoList(list5);

    await repository.moveTodoList(id2, 5);

    expect(await repository.getNumberOfTodoLists(), 5);
    var lists = await repository.getTodoListsChunk(0, 5);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list3.withId(id3));
    expect(lists[2], list4.withId(id4));
    expect(lists[3], list5.withId(id5));
    expect(lists[4], list2.withId(id2));
  });

  test('get reorder list mid up top test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var id4 = await repository.addTodoList(list4);
    var id5 = await repository.addTodoList(list5);

    await repository.moveTodoList(id3, 1);

    expect(await repository.getNumberOfTodoLists(), 5);
    var lists = await repository.getTodoListsChunk(0, 5);
    expect(lists[0], list3.withId(id3));
    expect(lists[1], list1.withId(id1));
    expect(lists[2], list2.withId(id2));
    expect(lists[3], list4.withId(id4));
    expect(lists[4], list5.withId(id5));
  });

  test('get reorder list bottom up test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var id4 = await repository.addTodoList(list4);
    var id5 = await repository.addTodoList(list5);

    await repository.moveTodoList(id5, 4);

    expect(await repository.getNumberOfTodoLists(), 5);
    var lists = await repository.getTodoListsChunk(0, 5);
    expect(lists[0], list1.withId(id1));
    expect(lists[1], list2.withId(id2));
    expect(lists[2], list3.withId(id3));
    expect(lists[3], list5.withId(id5));
    expect(lists[4], list4.withId(id4));
  });

  test('get reorder list bottom up top test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var id4 = await repository.addTodoList(list4);
    var id5 = await repository.addTodoList(list5);

    await repository.moveTodoList(id5, 1);

    expect(await repository.getNumberOfTodoLists(), 5);
    var lists = await repository.getTodoListsChunk(0, 5);
    expect(lists[0], list5.withId(id5));
    expect(lists[1], list1.withId(id1));
    expect(lists[2], list2.withId(id2));
    expect(lists[3], list3.withId(id3));
    expect(lists[4], list4.withId(id4));
  });

  test('get reorder list top down test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var id4 = await repository.addTodoList(list4);
    var id5 = await repository.addTodoList(list5);

    await repository.moveTodoList(id1, 2);

    expect(await repository.getNumberOfTodoLists(), 5);
    var lists = await repository.getTodoListsChunk(0, 5);
    expect(lists[0], list2.withId(id2));
    expect(lists[1], list1.withId(id1));
    expect(lists[2], list3.withId(id3));
    expect(lists[3], list4.withId(id4));
    expect(lists[4], list5.withId(id5));
  });

  test('get reorder list top down bottom test', () async {
    TodoList list1 = TodoList("test name 1", Palette.green);
    TodoList list2 = TodoList("test name 2", Palette.pink);
    TodoList list3 = TodoList("test name 3", Palette.blue);
    TodoList list4 = TodoList("test name 4", Palette.yellow);
    TodoList list5 = TodoList("test name 5", Palette.orange);

    var id1 = await repository.addTodoList(list1);
    var id2 = await repository.addTodoList(list2);
    var id3 = await repository.addTodoList(list3);
    var id4 = await repository.addTodoList(list4);
    var id5 = await repository.addTodoList(list5);

    await repository.moveTodoList(id1, 5);

    expect(await repository.getNumberOfTodoLists(), 5);
    var lists = await repository.getTodoListsChunk(0, 5);
    expect(lists[0], list2.withId(id2));
    expect(lists[1], list3.withId(id3));
    expect(lists[2], list4.withId(id4));
    expect(lists[3], list5.withId(id5));
    expect(lists[4], list1.withId(id1));
  });
}