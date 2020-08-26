import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:sqflite/sqflite.dart';

class ReminderDao {
  final Database _db;
  ReminderDao(this._db);

  Future<int> addReminder(int itemId, DateTime at) {
    return _db.insert(TODO_REMINDERS_TABLE, {TODO_REMINDER_ITEM: itemId, TODO_REMINDER_TIME: at.toIso8601String()});
  }

  Future<void> updateReminder(int reminderId, DateTime at) {
    return _db.update(TODO_REMINDERS_TABLE, {TODO_REMINDER_TIME: at.toIso8601String()}, where: "ID = ?", whereArgs: [reminderId]);
  }

  Future<void> deleteReminder(int reminderId) {
    return _db.delete(TODO_REMINDERS_TABLE, where: "ID = ?", whereArgs: [reminderId]);
  }

  Future<List<Reminder>> getReminders(int itemId) async {
    var results = await _db.query(TODO_REMINDERS_TABLE,
        columns: [TODO_REMINDER_TIME],
        where: "$TODO_REMINDER_ITEM = ?",
        whereArgs: [itemId]);
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
}