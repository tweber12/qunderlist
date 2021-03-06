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

import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/sqflite/reminder.dart';
import 'package:qunderlist/repository/sqflite/todo_item.dart';
import 'package:qunderlist/repository/sqflite/todo_list.dart';
import 'package:qunderlist/repository/sqflite/todo_list_item.dart';
import 'package:qunderlist/repository/todos_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const String _DEFAULT_DATABASE_NAME = "qunderlist_db.sqlite";

class TodoRepositorySqflite extends TodoRepository {
  static final TodoRepositorySqflite _repositorySqflite = TodoRepositorySqflite._internal();
  Database _db;
  TodoListDao listDao;
  TodoItemDao itemDao;
  ReminderDao reminderDao;
  TodoListItemDao listItemDao;

  static Future<TodoRepositorySqflite> getInstance({Database db}) async {
    if (db != null) {
      _repositorySqflite._db = db;
      await _repositorySqflite.init();
      return _repositorySqflite;
    }
    if (_repositorySqflite._db == null) {
      var path = await getDatabasesPath();
      var dbPath = join(path, _DEFAULT_DATABASE_NAME);
      _repositorySqflite._db = await openDatabase(dbPath, version: 1, onConfigure: configureDatabase, onCreate: createDatabase);
      await _repositorySqflite.init();
    }
    return _repositorySqflite;
  }

  Future<void> init() async {
    listDao = await TodoListDao.getInstance(_db);
    itemDao = TodoItemDao(_db);
    reminderDao = ReminderDao(_db);
    listItemDao = await TodoListItemDao.getInstance(_db);
  }

  TodoRepositorySqflite._internal();

  @override
  Future<TodoList> addTodoList(TodoList list) => listDao.addTodoList(list);

  @override
  Future<void> updateTodoList(TodoList list) => listDao.updateTodoList(list);

  @override
  Future<void> deleteTodoList(int listId) => listDao.deleteTodoList(listId);

  @override
  Future<void> moveTodoList(int listId, int moveTo) => listDao.moveTodoList(listId, moveTo);

  @override
  Future<int> getNumberOfTodoLists() => listDao.getNumberOfTodoLists();

  @override
  Future<TodoList> getTodoList(int id) => listDao.getTodoList(id);

  @override
  Future<TodoList> getTodoListByName(String name) => listDao.getTodoListByName(name);

  @override
  Future<List<TodoList>> getTodoListsChunk(int start, int end) => listDao.getTodoListsChunk(start, end);

  @override
  Future<List<TodoList>> getMatchingLists(String pattern, {int limit=5}) => listDao.getMatchingLists(pattern, limit);

  @override
  Future<int> getNumberOfOverdueItems(int listId) => listItemDao.getNumberOfOverdueItems(listId);

  @override
  Future<TodoItem> addTodoItem(TodoItem item, {TodoList onList}) async {
    var id;
    await _db.transaction((txn) async {
      assert(onList != null || item.onLists.isNotEmpty);
      id = await itemDao.addTodoItem(item, db: txn);
      if (onList != null) {
        await listItemDao.addItemToList(id, onList.id, db: txn);
        item = item.copyWith(onLists: [onList]);
      } else {
        for (final listId in item.onLists) {
          await listItemDao.addItemToList(id, listId.id, db: txn);
        }
      }
      item = item.copyWith(id: id);
      for (int i=0; i<item.reminders.length; i++) {
        var rid = await reminderDao.addReminder(id, item.reminders[i].at, txn: txn);
        item.reminders[i] = item.reminders[i].withId(rid);
      }
    });
    return item;
  }

  @override
  Future<void> updateTodoItem(TodoItemBase item) => itemDao.updateTodoItem(item);

  @override
  Future<void> updateRepeated(int itemId, Repeated repeated) => itemDao.updateRepeated(itemId, repeated);

  @override
  Future<void> deleteTodoItem(int itemId) => itemDao.deleteTodoItem(itemId);

  @override
  Future<TodoItem> getTodoItem(int itemId) => itemDao.getTodoItem(itemId);

  @override
  Future<int> addReminder(int itemId, DateTime at) => reminderDao.addReminder(itemId, at);

  @override
  Future<void> updateReminder(int reminderId, DateTime at) => reminderDao.updateReminder(reminderId, at);

  @override
  Future<void> deleteReminder(int reminderId) => reminderDao.deleteReminder(reminderId);

  @override
  Future<List<Reminder>> getRemindersForItem(int itemId) => reminderDao.getRemindersForItem(itemId);

  @override
  Future<List<Reminder>> getActiveRemindersForList(int listId) => reminderDao.getActiveRemindersForList(listId);

  @override
  Future<List<Reminder>> getActiveReminders() => reminderDao.getActiveReminders();

  @override
  Future<int> getItemOfReminder(int reminderId) => reminderDao.getItemOfReminder(reminderId);

  @override
  Future<void> addTodoItemToList(int itemId, int listId) => listItemDao.addItemToList(itemId, listId);

  @override
  Future<void> removeTodoItemFromList(int itemId, int listId) => listItemDao.removeTodoItemFromList(itemId, listId);

  @override
  Future<void> moveTodoItemToList(int itemId, int oldListId, int newListId) => listItemDao.moveTodoItemToList(itemId, oldListId, newListId);

  @override
  Future<void> moveTodoItemInList(int itemId, int listId, int moveToId) => listItemDao.moveTodoItemInList(itemId, listId, moveToId);

  @override
  Future<int> getNumberOfTodoItems(int listId, TodoStatusFilter filter) => listItemDao.getNumberOfTodoItems(listId, filter);

  @override
  Future<List<TodoItemShort>> getTodoItemsOfListChunk(int listId, int start, int end, TodoStatusFilter filter) => listItemDao.getTodoItemsOfListChunk(listId, start, end, filter);

  @override
  Future<List<TodoList>> getListsOfItem(int itemId) => listItemDao.getListsOfItem(itemId);

  @override
  Future<List<int>> getPendingItems({int listId}) => listItemDao.getPendingItems(listId: listId);
}