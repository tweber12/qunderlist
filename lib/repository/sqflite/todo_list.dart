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
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/utils/utils.dart';

class TodoListDao {
  final Database _db;
  int _maxOrdering;
  TodoListDao._internal(this._db);

  static Future<TodoListDao> getInstance(Database db) async {
    var todoListDao = TodoListDao._internal(db);
    todoListDao._maxOrdering = await todoListDao._getMaxOrdering();
    return todoListDao;
  }
  
  Future<int> addTodoList(TodoList list) async {
    // We need to increment maxOrdering here and store it, since the function could be interrupted at the await
    // This way, we keep the correct value and make sure that all other inserts start with the incremented one
    _maxOrdering += 1;
    var ordering = _maxOrdering;
    int id = await _db.insert(TODO_LISTS_TABLE, todoListToRepresentation(list, ordering: ordering));
    return id;
  }

  Future<void> updateTodoList(TodoList list) async {
    await _db.update(TODO_LISTS_TABLE, todoListToRepresentation(list), where: "$ID = ?", whereArgs: [list.id]);
  }

  Future<void> deleteTodoList(int listId) {
    // Do not touch maxOrdering, even though an item was deleted
    // The items are not reordered after a delete, so that the maximal ordering in use can be the same
    return _db.delete(TODO_LISTS_TABLE, where: "$ID = ?", whereArgs: [listId]);
  }

  Future<void> moveTodoList(int listId, int moveTo) async {
    // Move a list by shifting its ordering parameter
    // All lists between the original position of the list and it's new position are shifted up or down by one,
    // depending on if the list was moved up or down
    await _db.transaction((txn) async {
      var moveFrom = await _getOrderingOfList(txn, listId);
      if (moveFrom == moveTo) {
        return;
      }
      // The shifted lists have their ordering set to a negative temp value, because of an annoying sqlite feature
      // It checks uniqueness constraints per update, not per statement, so that incrementing or decrementing
      // consecutive items may fail, depending on the order in which the update is performed
      // Setting the changed value to be negative avoids the uniqueness issues even if 'n' is incremented before 'n+1'
      if (moveFrom > moveTo) {
        await _incrementOrderingBetween(txn, moveTo, moveFrom);
      } else {
        await _decrementOrderingBetween(txn, moveFrom, moveTo);
      }
      await _setOrdering(txn, listId, moveTo);
      // Make everything positive again
      await _absOrdering(txn);
    });
  }

  Future<TodoList> getTodoList(int id) async {
    var results = await _db.query(TODO_LISTS_TABLE,
        columns: [ID, TODO_LIST_NAME, TODO_LIST_COLOR], where: "$ID = ?", whereArgs: [id]);
    if (results.isEmpty) {
      return null;
    }
    return todoListFromRepresentation(results.first);
  }

  Future<TodoList> getTodoListByName(String name) async {
    var results = await _db.query(TODO_LISTS_TABLE,
        columns: [ID, TODO_LIST_NAME, TODO_LIST_COLOR], where: "$TODO_LIST_NAME = ?", whereArgs: [name]);
    if (results.isEmpty) {
      return null;
    }
    return todoListFromRepresentation(results.first);
  }

  Future<int> getNumberOfTodoLists() async {
    var results = await _db.query(TODO_LISTS_TABLE, columns: ["count(1)"]);
    return (firstIntValue(results) ?? 0);
  }

  Future<List<TodoList>> getTodoListsChunk(int start, int end) async {
    var results = await _db.query(
        TODO_LISTS_TABLE, columns: [ID, TODO_LIST_NAME, TODO_LIST_COLOR],
        orderBy: "$TODO_LIST_ORDERING asc",
        offset: start,
        limit: end - start);
    return results.map((m) => todoListFromRepresentation(m)).toList();
  }

  Future<List<TodoList>> getMatchingLists(String pattern, int limit) async {
    var results = await _db.query(
      TODO_LISTS_TABLE,
      columns: [ID, TODO_LIST_NAME, TODO_LIST_COLOR],
      where: "$TODO_LIST_NAME like ?",
      whereArgs: ["%"+pattern+"%"],
      orderBy: TODO_LIST_NAME,
      limit: limit,
    );
    return results.map((m) => todoListFromRepresentation(m)).toList();
  }

  Future<int> _getMaxOrdering() async {
    var results = await _db.query(TODO_LISTS_TABLE, columns: ["max($TODO_LIST_ORDERING)"]);
    return (firstIntValue(results) ?? 0);
  }

  Future<int> _getOrderingOfList(Transaction txn, int listId) async {
    var results = await txn.query(TODO_LISTS_TABLE, columns: [TODO_LIST_ORDERING], where: "$ID = ?", whereArgs: [listId]);
    return firstIntValue(results);
  }

  Future<void> _setOrdering(Transaction txn, int listId, int ordering) {
    return txn.update(TODO_LISTS_TABLE, {TODO_LIST_ORDERING: ordering}, where: "$ID = ?", whereArgs: [listId]);
  }

  Future<void> _incrementOrderingBetween(Transaction txn, int from, int to) {
    assert(from < to);
    return txn.rawUpdate("""
        update $TODO_LISTS_TABLE
           set $TODO_LIST_ORDERING = -($TODO_LIST_ORDERING+1)
         where $TODO_LIST_ORDERING >= ? and $TODO_LIST_ORDERING < ?;
      """, [from, to]);
  }

  Future<void> _decrementOrderingBetween(Transaction txn, int from, int to) {
    assert(from < to);
    return txn.rawUpdate("""
        update $TODO_LISTS_TABLE
           set $TODO_LIST_ORDERING = -($TODO_LIST_ORDERING-1)
         where $TODO_LIST_ORDERING > ? and $TODO_LIST_ORDERING <= ?;
      """, [from, to]);
  }

  Future<void> _absOrdering(Transaction txn) {
    return txn.rawUpdate("""
        update $TODO_LISTS_TABLE
           set $TODO_LIST_ORDERING = -$TODO_LIST_ORDERING
         where $TODO_LIST_ORDERING < 0;
      """);
  }
}