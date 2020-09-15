import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:sqflite/sqflite.dart';

class ReminderDao {
  final Database _db;
  ReminderDao(this._db);

  Future<int> addReminder(int itemId, DateTime at, {DatabaseExecutor txn}) {
    return (txn ?? _db).insert(TODO_REMINDERS_TABLE, {TODO_REMINDER_ITEM: itemId, TODO_REMINDER_TIME: at.toIso8601String()});
  }

  Future<void> updateReminder(int reminderId, DateTime at) {
    return _db.update(TODO_REMINDERS_TABLE, {TODO_REMINDER_TIME: at.toIso8601String()}, where: "ID = ?", whereArgs: [reminderId]);
  }

  Future<void> deleteReminder(int reminderId) {
    return _db.delete(TODO_REMINDERS_TABLE, where: "ID = ?", whereArgs: [reminderId]);
  }

  Future<List<Reminder>> getRemindersForItem(int itemId) async {
    var results = await _db.query(TODO_REMINDERS_TABLE,
        columns: [ID, TODO_REMINDER_TIME],
        where: "$TODO_REMINDER_ITEM = ?",
        whereArgs: [itemId]);
    return results.map(reminderFromRepresentation).toList();
  }

  Future<List<Reminder>> getActiveRemindersForList(int listId) async {
    var now = DateTime.now();
    var results = await _db.rawQuery("""
      select *
        from $TODO_REMINDERS_TABLE
             join $TODO_LIST_ITEMS_TABLE
               on $TODO_LIST_ITEMS_ITEM = $TODO_REMINDER_ITEM
       where $TODO_LIST_ITEMS_LIST = ? and $TODO_REMINDER_TIME > ?
    """, [listId, now.toIso8601String()]);
    return results.map(reminderFromRepresentation).toList();
  }

  Future<Map<int, List<Reminder>>> getRemindersForItems(List<int> itemIds) async {
    if (itemIds.isEmpty) {
      return Map();
    }
    var results = await _db.query(TODO_REMINDERS_TABLE,
        columns: [ID, TODO_REMINDER_TIME, TODO_REMINDER_ITEM],
        where: "$TODO_REMINDER_ITEM in (${itemIds.join(",")})",
        orderBy: TODO_REMINDER_ITEM);
    Map<int, List<Reminder>> reminders = Map();
    int id;
    List<Reminder> list = List();
    for (final result in results) {
      var rid = result[TODO_REMINDER_ITEM];
      if (rid != id) {
        if (list.isNotEmpty) {
          reminders[id] = list;
        }
        list = List();
        id = rid;
      }
      list.add(reminderFromRepresentation(result));
    }
    if (id != null) {
      reminders[id] = list;
    }
    return reminders;
  }

  Future<Map<int, int>> countActiveRemindersForItems(List<int> itemIds) async {
    if (itemIds.isEmpty) {
      return Map();
    }
    var now = DateTime.now().toIso8601String();
    var results = await _db.query(TODO_REMINDERS_TABLE,
        columns: [TODO_REMINDER_ITEM, "count(1)"],
        where: "$TODO_REMINDER_ITEM in (${itemIds.join(",")}) and $TODO_REMINDER_TIME > ?",
        groupBy: TODO_REMINDER_ITEM,
        whereArgs: [now]);
    Map<int, int> reminders = Map();
    for (final result in results) {
      var id = result[TODO_REMINDER_ITEM];
      reminders[id] = result["count(1)"];
    }
    return reminders;
  }
}