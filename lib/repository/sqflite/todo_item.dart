import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/sqflite/reminder.dart';
import 'package:sqflite/sqflite.dart';

class TodoItemDao {
  final Database _db;
  final ReminderDao _reminders;
  TodoItemDao(this._db): _reminders = ReminderDao(_db);

  Future<int> addTodoItem(TodoItem item, {DatabaseExecutor db}) async {
       return await (db ?? _db).insert(TODO_ITEMS_TABLE, todoItemToRepresentation(item));
  }

  Future<void> updateTodoItem(TodoItem item) async {
    await _db.update(TODO_ITEMS_TABLE, todoItemToRepresentation(item),
        where: "$ID = ?", whereArgs: [item.id]);
  }

  Future<void> deleteTodoItem(int itemId) async {
    await _db.delete(TODO_ITEMS_TABLE, where: "$ID = ?", whereArgs: [itemId]);
  }

  Future<TodoItem> getTodoItem(int itemId) async {
    var results = await _db.query(TODO_ITEMS_TABLE, where: "$ID = ?", whereArgs: [itemId]);
    if (results.isEmpty) {
      return null;
    }
    var reminders = await _reminders.getReminders(itemId);
    var todoItem = todoItemFromRepresentation(results.first, reminders);
    return todoItem;
  }
}