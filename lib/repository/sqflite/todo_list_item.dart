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
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/utils/utils.dart';

class TodoListItemDao {
  final Database _db;
  final ReminderDao reminderDao;
  final Map<int,int> _maxOrdering;

  TodoListItemDao._internal(this._db): _maxOrdering=Map(), reminderDao=ReminderDao(_db);

  static Future<TodoListItemDao> getInstance(Database db) async {
    var todoListItemDao = TodoListItemDao._internal(db);
    await todoListItemDao._getMaxOrdering();
    return todoListItemDao;
  }

  Future<void> addItemToList(int itemId, int listId, {DatabaseExecutor db}) {
    // We need to increment maxOrdering here and store it, since the function could be interrupted before the query
    // This way, we keep the correct value and make sure that all following inserts start with the incremented one
    var ordering = _maxOrdering.update(listId, (value) => value+1, ifAbsent: () => 1);
    var values = {
      TODO_LIST_ITEMS_LIST: listId,
      TODO_LIST_ITEMS_ITEM: itemId,
      TODO_LIST_ITEMS_ORDERING: ordering
    };
    return (db ?? _db).insert(TODO_LIST_ITEMS_TABLE, values);
  }

  Future<void> removeTodoItemFromList(int itemId, int listId, {DatabaseExecutor db}) {
    return (db ?? _db).delete(TODO_LIST_ITEMS_TABLE,
        where: "$TODO_LIST_ITEMS_LIST = ? and $TODO_LIST_ITEMS_ITEM = ?",
        whereArgs: [listId, itemId]);
  }

  Future<void> moveTodoItemToList(int itemId, int oldListId, int newListId) async {
    return _db.transaction((txn) async {
      await addItemToList(itemId, newListId, db: txn);
      await removeTodoItemFromList(itemId, oldListId, db: txn);
    });
  }

  Future<void> moveTodoItemInList(int itemId, int listId, int moveToId) async {
    // Move an item by shifting its ordering parameter
    // All items in the same list between the original position of the list and it's new position are shifted up or down by one,
    // depending on if the item was moved up or down
    await _db.transaction((txn) async {
      var moveFrom = await _getOrderingForItem(txn, itemId, listId);
      var moveTo = await _getOrderingForItem(txn, moveToId, listId);
      if (moveFrom == moveTo) {
        return;
      }
      // The shifted items have their ordering set to a negative temp value, because of an annoying sqlite feature
      // It checks uniqueness constraints per update, not per statement, so that incrementing or decrementing
      // consecutive items may fail, depending on the order in which the update is performed
      // Setting the changed value to be negative avoids the uniqueness issues even if 'n' is incremented before 'n+1'
      if (moveFrom > moveTo) {
        _incrementOrderingBetween(txn, listId, moveTo, moveFrom);
      } else {
        _decrementOrderingBetween(txn, listId, moveFrom, moveTo);
      }
      _setOrdering(txn, itemId, listId, moveTo);
      // Make everything positive again
      _absOrdering(txn, listId);
    });
  }

  Future<int> getNumberOfTodoItems(int listId, TodoStatusFilter filter) async {
    var result = await _queryFilteredListItems(listId, filter, columns: ["count(1)"]);
    return firstIntValue(result);
  }

  Future<List<TodoItemShort>> getTodoItemsOfListChunk(int listId, int start, int end, TodoStatusFilter filter) async {
    var results = await _queryFilteredListItems(listId, filter, ordered: true);
    var reminderMap = await reminderDao.countActiveRemindersForItems(results.map((m) => m[ID] as int).toList());
    var now = DateTime.now();
    var items = results.map((result) {
      var id = result[ID];
      var nActiveReminders = reminderMap[id] ?? 0;
      return todoItemShortFromRepresentation(result, nActiveReminders);
    }).toList();
    return items;
  }

  Future<List<TodoList>> getListsOfItem(int itemId) async {
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

  Future<int> getNumberOfOverdueItems(int listId) async {
    var now = DateTime.now();
    var today = DateTime(now.year, now.month, now.day);
    var results = await _db.rawQuery("""
          select count(1)
            from $TODO_ITEMS_TABLE
                 join $TODO_LIST_ITEMS_TABLE
                 on $ID = $TODO_LIST_ITEMS_ITEM
           where $TODO_LIST_ITEMS_LIST = ? and $TODO_ITEM_COMPLETED_DATE is null and $TODO_ITEM_DUE_DATE < ?
      """,
        [listId, today.toIso8601String()]);
    return firstIntValue(results);
  }

  Future<List<int>> getPendingItems({int listId}) async {
    List<Map<String,dynamic>> results;
    if (listId == null) {
      results = await _db.query(
          TODO_ITEMS_TABLE,
          where: "$TODO_ITEM_COMPLETED_DATE=null and $TODO_ITEM_REPEAT_ACTIVE=true and $TODO_ITEM_REPEAT_AUTO_ADVANCE=true"
      );
    } else {
      results = await _db.rawQuery("""
          select $ID
            from $TODO_ITEMS_TABLE
                 join $TODO_LIST_ITEMS_TABLE
                 on $ID = $TODO_LIST_ITEMS_ITEM
           where $TODO_ITEM_COMPLETED_DATE=null and $TODO_ITEM_REPEAT_ACTIVE=true and $TODO_ITEM_REPEAT_AUTO_ADVANCE=true and $TODO_LIST_ITEMS_LIST = ?
        """, [listId]);
    }
    return results.map((r) => r[ID] as int).toList();
  }

  Future<void> _getMaxOrdering() async {
    var results = await _db.rawQuery("""
        select $TODO_LIST_ITEMS_LIST, max($TODO_LIST_ITEMS_ORDERING)
          from $TODO_LIST_ITEMS_TABLE
      group by $TODO_LIST_ITEMS_LIST;
    """);
    for (final r in results) {
      var max = r["max($TODO_LIST_ITEMS_ORDERING)"];
      if (max == null) {
        continue;
      }
      _maxOrdering[r[TODO_LIST_ITEMS_LIST]] = max;
    }
  }

  Future<int> _getOrderingForItem(Transaction txn, int itemId, int listId) async {
    var results = await txn.query(TODO_LIST_ITEMS_TABLE, columns: [TODO_LIST_ITEMS_ORDERING],
        where: "$TODO_LIST_ITEMS_ITEM = ? and $TODO_LIST_ITEMS_LIST =?", whereArgs: [itemId, listId]);
    return firstIntValue(results);
  }

  Future<void> _setOrdering(Transaction txn, int itemId, int listId, int ordering) {
    return txn.update(
        TODO_LIST_ITEMS_TABLE, {TODO_LIST_ITEMS_ORDERING: ordering},
        where: "$TODO_LIST_ITEMS_ITEM = ?", whereArgs: [itemId]);
  }

  Future<void> _incrementOrderingBetween(Transaction txn, int listId, int from, int to) {
    assert(from < to);
    return txn.rawUpdate("""
        update $TODO_LIST_ITEMS_TABLE
           set $TODO_LIST_ITEMS_ORDERING = -($TODO_LIST_ITEMS_ORDERING+1)
         where $TODO_LIST_ITEMS_LIST = ? and $TODO_LIST_ITEMS_ORDERING >= ? and $TODO_LIST_ITEMS_ORDERING < ?;
      """, [listId, from, to]);
  }

  Future<void> _decrementOrderingBetween(Transaction txn, int listId, int from, int to) {
    assert(from < to);
    return txn.rawUpdate("""
        update $TODO_LIST_ITEMS_TABLE
           set $TODO_LIST_ITEMS_ORDERING = -($TODO_LIST_ITEMS_ORDERING-1)
         where $TODO_LIST_ITEMS_LIST = ? and $TODO_LIST_ITEMS_ORDERING > ? and $TODO_LIST_ITEMS_ORDERING <= ?;
      """, [listId, from, to]);
  }

  Future<void> _absOrdering(Transaction txn, int listId) {
    return txn.rawUpdate("""
        update $TODO_LIST_ITEMS_TABLE
           set $TODO_LIST_ITEMS_ORDERING = -$TODO_LIST_ITEMS_ORDERING
         where $TODO_LIST_ITEMS_LIST = ? and $TODO_LIST_ITEMS_ORDERING < 0;
      """, [listId]);
  }

  Future<List<Map<String,dynamic>>> _queryFilteredListItems(int listId, TodoStatusFilter filter, {List<String> columns, bool ordered=false}) {
    switch (filter) {
      case TodoStatusFilter.all:
        return _queryListItems(listId, columns: columns, orderBy: TODO_LIST_ITEMS_ORDERING);
      case TodoStatusFilter.active:
        return _queryListItems(listId, columns: columns, orderBy: TODO_LIST_ITEMS_ORDERING, where: "$TODO_ITEM_COMPLETED_DATE isnull");
      case TodoStatusFilter.completed:
        return _queryListItems(listId, columns: columns, orderBy: "$TODO_ITEM_COMPLETED_DATE desc, $TODO_LIST_ITEMS_ORDERING", where: "$TODO_ITEM_COMPLETED_DATE not null");
      case TodoStatusFilter.important:
        return _queryListItems(listId, columns: columns, orderBy: "$TODO_ITEM_PRIORITY asc, $TODO_LIST_ITEMS_ORDERING", where: "$TODO_ITEM_COMPLETED_DATE isnull and $TODO_ITEM_PRIORITY != ?", whereArgs: [TodoPriority.none.index]);
      case TodoStatusFilter.withDueDate:
        return _queryListItems(listId, columns: columns, orderBy: TODO_ITEM_DUE_DATE, where: "$TODO_ITEM_COMPLETED_DATE isnull and $TODO_ITEM_DUE_DATE not null");
      default:
        throw "BUG: Unhandled status filter in query";
    }
  }
  
  Future<List<Map<String,dynamic>>> _queryListItems(int listId, {List<String> columns, String where, List<dynamic> whereArgs, String orderBy}) {
    var query = """
          select ${columns == null || columns.isEmpty ? "*" : columns.join(", ")}
            from $TODO_ITEMS_TABLE
                 join $TODO_LIST_ITEMS_TABLE
                   on $ID = $TODO_LIST_ITEMS_ITEM
           where $TODO_LIST_ITEMS_LIST = ?
        """;
    var args = [listId.toString()];
    if (where != null) {
      query += "and $where";
      if (whereArgs != null) {
        args.addAll(whereArgs.map((a) => a.toString()));
      }
    }
    if (orderBy != null) {
      query += " order by $orderBy";
    }
    return _db.rawQuery(query, args);
  }
}