import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/sqflite/database.dart';
import 'package:qunderlist/repository/sqflite/reminder.dart';
import 'package:qunderlist/repository/sqflite/todo_item.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Database db;
  ReminderDao dao;
  List<int> itemIds;
  Map<int,List<Reminder>> reminders = Map();

  // Init ffi loader if needed.
  sqfliteFfiInit();
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: createDatabase, onConfigure: configureDatabase));
    dao = ReminderDao(db);
    var now = DateTime.now();
    var itemDao = TodoItemDao(db);
    itemIds = List();
    for (int i=0; i<3; i++) {
      itemIds.add(await itemDao.addTodoItem(TodoItem("item $i", now)));
    }
    var s = 2;
    for (final itemId in itemIds) {
      var r = List<Reminder>();
      for (int i=0; i<s; i++) {
        var date = now.add(Duration(days: i));
        var id = await dao.addReminder(itemId, date);
        r.add(Reminder(date, id: id));
      }
      s+=1;
      reminders[itemId] = r;
    }
  });
  tearDown(() async {
    await db.close();
    db = null;
    dao = null;
    itemIds = null;
  });

  test('get reminders test', () async {
    for (final itemId in itemIds) {
      var resultReminders = await dao.getReminders(itemId);
      resultReminders.sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders, reminders[itemId]);
    }
  });

  test('get reminders for items all test', () async {
    for (final itemId in itemIds) {
      var resultReminders = await dao.getRemindersForItems(itemIds);
      expect(resultReminders.length, itemIds.length);
      for (final itemId in itemIds) {
        resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
        expect(resultReminders[itemId], reminders[itemId]);
      }
    }
  });

  test('get reminders for items two test', () async {
    for (final itemId in itemIds) {
      var resultReminders = await dao.getRemindersForItems(itemIds.skip(1).toList());
      expect(resultReminders.length, itemIds.length-1);
      for (final itemId in resultReminders.keys) {
        resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
        expect(resultReminders[itemId], reminders[itemId]);
      }
    }
  });

  test('delete reminders test', () async {
    var delId = itemIds.last;
    await dao.deleteReminder(reminders[delId][1].id);
    reminders[delId].removeAt(1);
    await dao.deleteReminder(reminders[delId][2].id);
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
      await dao.deleteReminder(reminder.id);
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
    var resultDeleted = await dao.getReminders(delId);
    expect(resultDeleted, []);
  });

  test('update reminders test', () async {
    var now = DateTime.now();
    await dao.updateReminder(reminders[2][0].id, now);
    reminders[2][0] = reminders[2][0].copyWith(at: now);
    await dao.updateReminder(reminders[1][1].id, now.add(Duration(hours: 3)));
    reminders[1][1] = reminders[1][1].copyWith(at: now.add(Duration(hours: 3)));
    var resultReminders = await dao.getRemindersForItems(itemIds);
    for (final itemId in resultReminders.keys) {
      resultReminders[itemId].sort((a,b) => a.id.compareTo(b.id));
      expect(resultReminders[itemId], reminders[itemId]);
    }
  });
}