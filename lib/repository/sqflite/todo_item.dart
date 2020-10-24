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

import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/sqflite/reminder.dart';
import 'package:sqflite/sqflite.dart';

class TodoItemDao {
  final Database _db;
  final ReminderDao _reminders;
  TodoItemDao(this._db): _reminders = ReminderDao(_db);

  Future<int> addTodoItem(TodoItem item, {DatabaseExecutor db}) async {
    var repository = todoItemToRepresentation(item);
    repository.addAll(repeatedToRepresentation(item.repeated));
    return await (db ?? _db).insert(TODO_ITEMS_TABLE, repository);
  }

  Future<void> updateTodoItem(TodoItemBase item) async {
    await _db.update(TODO_ITEMS_TABLE, todoItemToRepresentation(item),
        where: "$ID = ?", whereArgs: [item.id]);
  }

  Future<void> updateRepeated(int itemId, Repeated repeated) async {
    await _db.update(TODO_ITEMS_TABLE, repeatedToRepresentation(repeated),
        where: "$ID = ?", whereArgs: [itemId]);
  }

  Future<void> deleteTodoItem(int itemId) async {
    await _db.delete(TODO_ITEMS_TABLE, where: "$ID = ?", whereArgs: [itemId]);
  }

  Future<TodoItem> getTodoItem(int itemId) async {
    var results = await _db.query(TODO_ITEMS_TABLE, where: "$ID = ?", whereArgs: [itemId]);
    if (results.isEmpty) {
      return null;
    }
    var reminders = await _reminders.getRemindersForItem(itemId);
    var onLists = await _getListsOfItem(itemId);
    var todoItem = todoItemFromRepresentation(results.first, reminders, onLists);
    return todoItem;
  }

  Future<List<TodoList>> _getListsOfItem(int itemId) async {
    var results = await _db.rawQuery("""
          select $ID, $TODO_LIST_NAME, $TODO_LIST_COLOR
            from $TODO_LISTS_TABLE
                 join $TODO_LIST_ITEMS_TABLE
                 on $ID = $TODO_LIST_ITEMS_LIST
           where $TODO_LIST_ITEMS_ITEM = ?
        order by $TODO_LIST_ORDERING asc;
      """,
        [itemId]);
    return results.map((m) => todoListFromRepresentation(m)).toList();
  }
}