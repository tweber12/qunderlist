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
import 'package:qunderlist/repository/sqflite/reminder.dart';
import 'package:qunderlist/repository/sqflite/todo_item.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Database db;
  TodoRepositorySqflite repository;
  ReminderDao dao;
  List<int> itemIds;
  Map<int,List<Reminder>> reminders = Map();

  // Init ffi loader if needed.
  sqfliteFfiInit();
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: createDatabase, onConfigure: configureDatabase));
    repository = await TodoRepositorySqflite.getInstance(db: db);
    dao = repository.reminderDao;
    var now = DateTime.now();
    var itemDao = repository.itemDao;
    itemIds = List();
    for (int i=0; i<3; i++) {
      itemIds.add(await itemDao.addTodoItem(TodoItem("item $i", now)));
    }
    var s = 2;
    for (final itemId in itemIds) {
      var r = List<Reminder>();
      var date;
      for (int i=0; i<s; i++) {
        if (i%2==0) {
          date = now.add(Duration(days: i+1));
        } else {
          date = now.subtract(Duration(days: i+1));
        }
        var id = await repository.addReminder(itemId, date);
        r.add(Reminder(date, id: id));
      }
      s+=1;
      reminders[itemId] = r;
    }
  });
  tearDown(() async {
    await db.close();
    db = null;
    repository = null;
    itemIds = null;
  });

  test('get reminders test', () async {
    for (final itemId in itemIds) {
      var resultReminders = await repository.getRemindersForItem(itemId);
      resultReminders.sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders, reminders[itemId]);
    }
  });

  test('get reminders for items all test', () async {
    var resultReminders = await dao.getRemindersForItems(itemIds);
    expect(resultReminders.length, itemIds.length);
    for (final itemId in itemIds) {
      resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders[itemId], reminders[itemId]);
    }
  });

  test('get reminders for items two test', () async {
    var resultReminders = await dao.getRemindersForItems(itemIds.skip(1).toList());
    expect(resultReminders.length, itemIds.length-1);
    for (final itemId in resultReminders.keys) {
      resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders[itemId], reminders[itemId]);
    }
  });


  test('count active reminders for items all test', () async {
    var resultReminders = await dao.countActiveRemindersForItems(itemIds);
    expect(resultReminders.length, itemIds.length);
    var now = DateTime.now();
    for (final itemId in itemIds) {
      var expected = reminders[itemId].where((element) => element.at.isAfter(now)).length;
      expect(resultReminders[itemId], expected);
    }
  });

  test('delete reminders test', () async {
    var delId = itemIds.last;
    await repository.deleteReminder(reminders[delId][1].id);
    reminders[delId].removeAt(1);
    await repository.deleteReminder(reminders[delId][2].id);
    reminders[delId].removeAt(2);
    var resultReminders = await dao.getRemindersForItems(itemIds);
    expect(resultReminders.length, itemIds.length);
    for (final itemId in resultReminders.keys) {
      resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders[itemId], reminders[itemId]);
    }
  });

  test('delete all reminders of item test', () async {
    var delId = itemIds.last;
    for (final reminder in reminders[delId]) {
      await repository.deleteReminder(reminder.id);
    }
    var resultReminders = await dao.getRemindersForItems(itemIds);
    expect(resultReminders.length, itemIds.length-1);
    for (final itemId in resultReminders.keys.where((element) => element != delId)) {
      resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders[itemId], reminders[itemId]);
    }
    expect(resultReminders[delId], null);
  });

  test('delete item cascade test', () async {
    var delId = itemIds.last;
    var listDao = TodoItemDao(db);
    await listDao.deleteTodoItem(delId);
    var resultReminders = await dao.getRemindersForItems(itemIds);
    expect(resultReminders.length, itemIds.length-1);
    for (final itemId in resultReminders.keys.where((element) => element != delId)) {
      resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders[itemId], reminders[itemId]);
    }
    expect(resultReminders[delId], null);
    var resultDeleted = await repository.getRemindersForItem(delId);
    expect(resultDeleted, []);
  });

  test('update reminders test', () async {
    var now = DateTime.now();
    await repository.updateReminder(reminders[2][0].id, now);
    reminders[2][0] = reminders[2][0].copyWith(at: now);
    await repository.updateReminder(reminders[1][1].id, now.add(Duration(hours: 3)));
    reminders[1][1] = reminders[1][1].copyWith(at: now.add(Duration(hours: 3)));
    var resultReminders = await dao.getRemindersForItems(itemIds);
    for (final itemId in resultReminders.keys) {
      resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders[itemId], reminders[itemId]);
    }
  });

  test("get reminders for list", () async {
    var itemId1 = itemIds[0];
    var itemId2 = itemIds[2];
    int listId = await repository.addTodoList(TodoList("test", Palette.amber));
    repository.addTodoItemToList(itemId1, listId);
    repository.addTodoItemToList(itemId2, listId);
    var now = DateTime.now();
    var resultReminders = await repository.getActiveRemindersForList(listId);
    var active = (reminders[itemId1]+reminders[itemId2]).where((element) => element.at.isAfter(now)).toList();
    expect(resultReminders.length, active.length);
    for (final item in active) {
      expect(resultReminders.contains(item), true);
    }
  });
}