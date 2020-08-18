import 'package:qunderlist/repository/repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const String _DEFAULT_DATABASE_NAME = "qunderlist_db.sqlite";

const String ID = "id";

const String TODO_LISTS_TABLE = "todo_lists";
const String TODO_LIST_NAME = "list_name";
const String TODO_LIST_ORDERING = "list_ordering";

const String TODO_ITEMS_TABLE = "todo_items";
const String TODO_ITEM_NAME = "item_name";
const String TODO_ITEM_COMPLETED = "item_complete";
const String TODO_ITEM_PRIORITY = "item_priority";
const String TODO_ITEM_NOTE = "item_note";
const String TODO_ITEM_DUE_DATE = "item_due";
const String TODO_ITEM_CREATED_DATE = "item_created_date";
const String TODO_ITEM_COMPLETED_DATE = "item_completed_date";

const String TODO_LIST_ITEMS_TABLE = "todo_list_items";
const String TODO_LIST_ITEMS_LIST = "list_items_list";
const String TODO_LIST_ITEMS_ITEM = "list_items_item";
const String TODO_LIST_ITEMS_ORDERING = "list_items_ordering";

const String TODO_REMINDERS_TABLE = "todo_reminders";
const String TODO_REMINDER_ITEM = "reminder_item";
const String TODO_REMINDER_TIME = "reminder_time";

class TodoRepositorySqflite implements TodoRepository {
  static final TodoRepositorySqflite _repositorySqflite =
      TodoRepositorySqflite._internal();
  Future<Database> _db;
  int _lastOrderingOfLists;
  Map<int, int> _lastOrderingInList = {};

  static TodoRepositorySqflite getInstance({Database db}) {
    if (db != null) {
      _repositorySqflite._db = Future.value(db);
      return _repositorySqflite;
    }
    if (_repositorySqflite._db == null) {
      _repositorySqflite._db = getDatabasesPath().then((value) {
        var dbPath = join(value, _DEFAULT_DATABASE_NAME);
        return openDatabase(dbPath, version: 1, onCreate: createDatabase);
      });
    }
    return _repositorySqflite;
  }

  TodoRepositorySqflite._internal();

  @override
  Future<int> addTodoItem(TodoItem item, int listId) async {
    var db = await _db;
    var id;
    await db.transaction((txn) async {
      id = await txn.insert(TODO_ITEMS_TABLE, _todoItemToRepresentation(item));
      await _addReminders(id, item.reminders, txn: txn);
      await _addTodoItemToList(listId, id, txn: txn);
    });
    return id;
  }

  @override
  Future<void> updateTodoItem(TodoItem item) async {
    var db = await _db;
    await db.transaction((txn) async {
      await txn.update(TODO_ITEMS_TABLE, _todoItemToRepresentation(item),
          where: "$ID = ?", whereArgs: [item.id]);
      await _updateReminders(item.id, item.reminders, txn: txn);
    });
  }

  @override
  Future<void> completeTodoItem(TodoItem item) async {
    var db = await _db;
    var completedDate = item.completed ? null : DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(TODO_ITEMS_TABLE, {TODO_ITEM_COMPLETED: item.completed ? 0 : 1, TODO_ITEM_COMPLETED_DATE: completedDate}, where: "$ID = ?", whereArgs: [item.id]);
    });
  }

  @override
  Future<void> deleteTodoItem(TodoItem item) async {
    var db = await _db;
    await db.transaction((txn) async {
      await _deleteTodoItem(item.id, txn);
    });
  }

  @override
  Future<TodoItem> getTodoItem(int id) async {
    var db = await _db;
    var results = await db.query(TODO_ITEMS_TABLE,
        columns: [
          ID,
          TODO_ITEM_NAME,
          TODO_ITEM_COMPLETED,
          TODO_ITEM_PRIORITY,
          TODO_ITEM_NOTE,
          TODO_ITEM_DUE_DATE,
          TODO_ITEM_CREATED_DATE,
          TODO_ITEM_COMPLETED_DATE
        ],
        where: "$ID = ?",
        whereArgs: [id]);
    if (results.isEmpty) {
      return null;
    }
    var reminders = await _getReminders(db, id);
    var todoItem = _todoItemFromRepresentation(results.first, reminders);
    return todoItem;
  }

  @override
  Future<void> addTodoList(TodoList list) async {
    var db = await _db;
    await db.transaction((txn) async{
      int ordering = await _lookupLastOrderingOfLists(txn);
      print("next ordering: ${ordering+1}");
      await txn.insert(TODO_LISTS_TABLE, _todoListToRepresentation(list, ordering: ordering+1));
      _lastOrderingOfLists = ordering+1;
    });
  }

  @override
  Future<void> updateTodoList(TodoList list) async {
    var db = await _db;
    await db.update(TODO_LISTS_TABLE, _todoListToRepresentation(list),
        where: "$ID = ?", whereArgs: [list.id]);
  }

  Future<void> deleteTodoList(TodoList list) async {
    var db = await _db;
    // Restore ordering
    await db.transaction((txn) async {
      await txn.rawUpdate("""
        update $TODO_LISTS_TABLE
           set $TODO_LIST_ORDERING = $TODO_LIST_ORDERING-1
         where $TODO_LIST_ORDERING > (select $TODO_LIST_ORDERING from $TODO_LISTS_TABLE where $ID=?);
        """, [list.id]);
      // Delete list
      await txn
          .delete(TODO_LISTS_TABLE, where: "$ID = ?", whereArgs: [list.id]);
      // Reduce the stored number of lists by one
      if (_lastOrderingOfLists != null) {
        _lastOrderingOfLists -= 1;
      }
      // Delete connection between list and items
      await txn.delete(TODO_LIST_ITEMS_TABLE,
          where: "$TODO_LIST_ITEMS_LIST = ?", whereArgs: [list.id]);
      // Delete now orphaned items
      await txn.rawQuery(
          """delete from $TODO_ITEMS_TABLE  where $ID in (select $ID from $TODO_ITEMS_TABLE left outer join $TODO_LIST_ITEMS_TABLE on $ID = $TODO_LIST_ITEMS_ITEM where $TODO_LIST_ITEMS_ITEM is null)""");
    });
  }

  @override
  Future<void> moveList(TodoList list, int moveTo) async {
    var db = await _db;
    await db.transaction((txn) async {
      var ordering = await txn.query(TODO_LISTS_TABLE,
          columns: [TODO_LIST_ORDERING],
          where: "$ID = ?",
          whereArgs: [list.id]);
      var position = ordering.first[TODO_LIST_ORDERING];
      print("MOVE $position => $moveTo");
      if (position > moveTo) {
        await txn.rawUpdate("""
            update $TODO_LISTS_TABLE
               set $TODO_LIST_ORDERING = $TODO_LIST_ORDERING+1
             where $TODO_LIST_ORDERING < ? and $TODO_LIST_ORDERING >= ?;
          """, [position, moveTo]);
      } else if (position < moveTo) {
        await txn.rawUpdate("""
            update $TODO_LISTS_TABLE
               set $TODO_LIST_ORDERING = $TODO_LIST_ORDERING-1
             where $TODO_LIST_ORDERING > ? and $TODO_LIST_ORDERING <= ?;
          """, [position, moveTo]);
      }
      await txn.update(
          TODO_LISTS_TABLE, {TODO_LIST_ORDERING: moveTo},
          where: "$ID = ?", whereArgs: [list.id]);
    });
  }

  @override
  Future<TodoList> getTodoList(int id) async {
    var db = await _db;
    var results = await db.query(TODO_LISTS_TABLE,
        columns: [ID, TODO_LIST_NAME], where: "$ID = ?", whereArgs: [id]);
    if (results.isEmpty) {
      return null;
    }
    return _todoListFromRepresentation(results.first);
  }

  @override
  Future<int> getNumberOfTodoLists() async {
    var db = await _db;
    var results = await db.rawQuery("""select count($ID) from $TODO_LISTS_TABLE""");
    if (results.isEmpty) {
      return 0;
    } else {
      var num = results.first["count($ID)"];
      return num ?? 0;
    }
  }

  @override
  Future<List<int>> getTodoLists() async {
    var db = await _db;
    var results = await db.query(TODO_LISTS_TABLE, columns: [ID], orderBy: "$TODO_LIST_ORDERING asc");
    return results.map((m) => m[ID] as int).toList();
  }

  @override
  Future<List<TodoList>> getTodoListsChunk(int start, int end) async {
    var db = await _db;
    var results = await db.query(TODO_LISTS_TABLE, columns: [ID,TODO_LIST_NAME,TODO_LIST_ORDERING], orderBy: "$TODO_LIST_ORDERING asc", offset: start, limit: end-start);
    for (final r in results) {
      print("ORDERING ${r[TODO_LIST_NAME]} => ${r[TODO_LIST_ORDERING]}");
    }
    return results.map((m) => _todoListFromRepresentation(m)).toList();
  }

  @override
  Future<int> getNumberOfItems(int listId, {TodoStatusFilter filter: TodoStatusFilter.all}) async {
    var db = await _db;
    var result = await _ItemsQuery(listId: listId, filter: filter).getNumberOfItems(db);
    return result;
  }

  @override
  Future<List<int>> getTodoItemsOfList(int listId, {TodoStatusFilter filter = TodoStatusFilter.all}) async {
    var db = await _db;
    var result = await _ItemsQuery(listId: listId, filter: filter).getTodoItems(db);
    return result;
  }

  @override
  Future<List<TodoItem>> getTodoItemsOfListChunk(int listId, int start, int end, {TodoStatusFilter filter = TodoStatusFilter.all}) async {
    var db = await _db;
    var result = await _ItemsQuery(listId: listId, filter: filter, offset: start, limit: end-start).getChunkOfTodoItems(db);
    return result;
  }

  @override
  Future<List<TodoList>> getListsOfItem(int itemId) async {
    var db = await _db;
    var results = await db.rawQuery("""
          select $ID, $TODO_LIST_NAME
            from $TODO_LISTS_TABLE
            join $TODO_LIST_ITEMS_TABLE
              on $ID = $TODO_LIST_ITEMS_LIST
           where $TODO_LIST_ITEMS_ITEM = ?
        order by $TODO_LIST_ORDERING asc;
      """,
      [itemId]);
    return results.map((m) => _todoListFromRepresentation(m)).toList();
  }

  @override
  Future<void> addTodoItemToList(TodoItem item, int listId) async {
    return _addTodoItemToList(listId, item.id);
  }

  @override
  Future<void> removeTodoItemFromList(TodoItem item, int listId) async {
    var db = await _db;
    await db.transaction((txn) async {
      await _removeTodoItemFromList(txn, listId, item.id, recursive: true);
    });
  }

  @override
  Future<void> moveTodoItemToList(
      TodoItem item, int oldListId, int newListId) async {
    var db = await _db;
    await db.transaction((txn) async {
      await _removeTodoItemFromList(txn, oldListId, item.id);
      await _addTodoItemToList(newListId, item.id, txn: txn);
    });
  }

  @override
  Future<void> moveItemInList(TodoItem item, int listId, int moveToId) async {
    print("REORDER: ${item.id}, $moveToId");
    var db = await _db;
    await db.transaction((txn) async {
      var ordering = await txn.query(TODO_LIST_ITEMS_TABLE,
          columns: [TODO_LIST_ITEMS_ORDERING],
          where: "$TODO_LIST_ITEMS_ITEM = ? or $TODO_LIST_ITEMS_ITEM = ?",
          whereArgs: [item.id, moveToId]);
      var position;
      var moveTo;
      if (ordering[0][ID] == item.id) {
        position = ordering[0][TODO_LIST_ITEMS_ORDERING];
        moveTo = ordering[1][TODO_LIST_ITEMS_ORDERING];
      } else {
        position = ordering[1][TODO_LIST_ITEMS_ORDERING];
        moveTo = ordering[0][TODO_LIST_ITEMS_ORDERING];
      }
      print("REORDER: $position -> $moveTo");
      if (position > moveTo) {
        await txn.rawUpdate("""
            update $TODO_LIST_ITEMS_TABLE
               set $TODO_LIST_ITEMS_ORDERING = $TODO_LIST_ITEMS_ORDERING+1
             where $TODO_LIST_ITEMS_ORDERING < ? and $TODO_LIST_ITEMS_ORDERING >= ?;
          """, [position, moveTo]);
      } else if (position < moveTo) {
        await txn.rawUpdate("""
            update $TODO_LIST_ITEMS_TABLE
               set $TODO_LIST_ITEMS_ORDERING = $TODO_LIST_ITEMS_ORDERING-1
             where $TODO_LIST_ITEMS_ORDERING > ? and $TODO_LIST_ITEMS_ORDERING <= ?;
          """, [position, moveTo]);
      }
      await txn.update(
          TODO_LIST_ITEMS_TABLE, {TODO_LIST_ITEMS_ORDERING: moveTo},
          where: "$TODO_LIST_ITEMS_ITEM = ?", whereArgs: [item.id]);
    });
  }

  @override
  Future<void> moveItemToTopOfList(TodoItem item, int listId, {int offset}) async {
    var moveTo = 1 + (offset ?? 0);
    return moveItemInList(item, listId, moveTo);
  }


  @override
  Future<void> moveItemToBottomOfList(TodoItem item, int listId, {int offset}) async {
    var lastOrderId = _lastOrderingInList[listId];
    if (lastOrderId == null) {
      lastOrderId = await _lookupLastOrderingInList(listId);
      _lastOrderingInList[listId] = lastOrderId;
    }
    var moveTo = lastOrderId - (offset ?? 0);
    return moveItemInList(item, listId, moveTo);
  }

  Future<void> _removeTodoItemFromList(Transaction txn, int listId, int itemId,
      {bool recursive = false}) async {
    await txn.rawUpdate("""
        update $TODO_LIST_ITEMS_TABLE
           set $TODO_LIST_ITEMS_ORDERING = $TODO_LIST_ITEMS_ORDERING-1
         where $TODO_LIST_ITEMS_LIST = ? and $TODO_LIST_ITEMS_ORDERING > (select $TODO_LIST_ITEMS_ORDERING from $TODO_LIST_ITEMS_TABLE where $TODO_LIST_ITEMS_LIST = ? and $TODO_LIST_ITEMS_ITEM = ?)
      """, [listId, listId, itemId]);
    if (_lastOrderingInList[listId] != null) {
      _lastOrderingInList[listId] -= 1;
    }
    await txn.delete(TODO_LIST_ITEMS_TABLE,
        where: "$TODO_LIST_ITEMS_LIST = ? and $TODO_LIST_ITEMS_ITEM = ?",
        whereArgs: [listId, itemId]);
    if (recursive) {
      var count = await txn.rawQuery("""
            select (count($TODO_LIST_ITEMS_LIST))
              from $TODO_LIST_ITEMS_TABLE
             where $TODO_LIST_ITEMS_ITEM = ?;
          """, [itemId]);
      if (count == null || count.first[TODO_LIST_ITEMS_LIST] == 0) {
        return _deleteTodoItem(itemId, txn);
      }
    }
  }

  Future<List<int>> _listsForTodoItem(Transaction txn, int itemId) async {
    var results = await txn.query(TODO_LIST_ITEMS_TABLE,
        columns: [TODO_LIST_ITEMS_LIST],
        where: "$TODO_LIST_ITEMS_ITEM = ?",
        whereArgs: [itemId]);
    return results.map((m) => m[TODO_LIST_ITEMS_LIST] as int).toList();
  }

  Future<void> _deleteTodoItem(int itemId, Transaction txn) async {
    var lists = await _listsForTodoItem(txn, itemId);
    for (final list in lists) {
      _removeTodoItemFromList(txn, list, itemId);
    }
    await txn.delete(TODO_ITEMS_TABLE, where: "$ID = ?", whereArgs: [itemId]);
    await _deleteReminders(itemId, txn: txn);
  }

  Future<void> _addTodoItemToList(int listId, int itemId,
      {Transaction txn}) async {
    var db = txn ?? await _db;
    var lastOrderId =
        _lastOrderingInList[listId] ?? await _lookupLastOrderingInList(listId, txn: txn);
    await db.insert(TODO_LIST_ITEMS_TABLE, {
      TODO_LIST_ITEMS_LIST: listId,
      TODO_LIST_ITEMS_ITEM: itemId,
      TODO_LIST_ITEMS_ORDERING: lastOrderId + 1
    });
    _lastOrderingInList[listId] = lastOrderId + 1;
  }

  Future<void> _addReminders(int itemId, List<DateTime> reminders,
      {Transaction txn}) async {
    var db = txn ?? await _db;
    var batch = db.batch();
    for (final reminder in reminders) {
      batch.insert(TODO_REMINDERS_TABLE, {
        TODO_REMINDER_ITEM: itemId,
        TODO_REMINDER_TIME: reminder.toIso8601String()
      });
    }
    await batch.commit();
  }

  Future<void> _updateReminders(int itemId, List<DateTime> reminders,
      {Transaction txn}) async {
    if (txn == null) {
      var db = await _db;
      await db.transaction((txn) => _updateRemindersTxn(txn, itemId, reminders));
    } else {
      await _updateRemindersTxn(txn, itemId, reminders);
    }
  }

  Future<void> _updateRemindersTxn(
      Transaction txn, int itemId, List<DateTime> reminders) async {
    await _deleteReminders(itemId, txn: txn);
    await _addReminders(itemId, reminders, txn: txn);
  }

  Future<void> _deleteReminders(int itemId, {Transaction txn}) async {
    var db = txn ?? await _db;
    await db.delete(TODO_REMINDERS_TABLE,
        where: "$TODO_REMINDER_ITEM = ?", whereArgs: [itemId]);
  }

  Future<int> _lookupLastOrderingOfLists(Transaction txn) async {
    print("STORED: $_lastOrderingOfLists");
    if (_lastOrderingOfLists != null) {
      return _lastOrderingOfLists;
    }
    var results = await txn.rawQuery("""
        select count($ID)
          from $TODO_LISTS_TABLE
      """);
    if (results.isEmpty) {
      _lastOrderingOfLists = 0;
    } else {
      _lastOrderingOfLists = results.first["count($ID)"] ?? 0;
    }
    print("COUNTED: $_lastOrderingOfLists");
    return _lastOrderingOfLists;
  }

  Future<int> _lookupLastOrderingInList(int listId, {Transaction txn}) async {
    var db = txn ?? await _db;
    var results = await db.rawQuery("""
        select max($TODO_LIST_ITEMS_ORDERING)
          from $TODO_LIST_ITEMS_TABLE
         where $TODO_LIST_ITEMS_LIST = ?;
      """, [listId]);
    print(results);
    if (results.isEmpty || results.first["max($TODO_LIST_ITEMS_ORDERING)"] == null) {
      return 0;
    } else {
      return results.first["max($TODO_LIST_ITEMS_ORDERING)"];
    }
  }
}

Map<String, dynamic> _todoItemToRepresentation(TodoItem item) {
  var map = {
    TODO_ITEM_NAME: item.todo,
    TODO_ITEM_COMPLETED: item.completed ? 1 : 0,
    TODO_ITEM_PRIORITY: item.priority.index,
    TODO_ITEM_NOTE: item.note,
    TODO_ITEM_DUE_DATE:
        item.dueDate == null ? null : item.dueDate.toIso8601String(),
    TODO_ITEM_CREATED_DATE: item.createdOn.toIso8601String(),
    TODO_ITEM_COMPLETED_DATE:
        item.completedOn == null ? null : item.completedOn.toIso8601String(),
  };
  return map;
}

TodoItem _todoItemFromRepresentation(
    Map<String, dynamic> representation, List<DateTime> reminders) {
  return TodoItem(
    representation[TODO_ITEM_NAME],
    DateTime.parse(representation[TODO_ITEM_CREATED_DATE]),
    id: representation[ID],
    completed: representation[TODO_ITEM_COMPLETED] == 1,
    priority: TodoPriority.values[representation[TODO_ITEM_PRIORITY]],
    note: representation[TODO_ITEM_NOTE],
    dueDate: representation[TODO_ITEM_DUE_DATE] == null
        ? null
        : DateTime.parse(representation[TODO_ITEM_DUE_DATE]),
    completedOn: representation[TODO_ITEM_COMPLETED_DATE] == null
        ? null
        : DateTime.parse(representation[TODO_ITEM_COMPLETED_DATE]),
    reminders: reminders,
  );
}

Map<String, dynamic> _todoListToRepresentation(TodoList list, {int ordering}) {
  Map<String,dynamic> map = {
    TODO_LIST_NAME: list.listName,
  };
  if (ordering != null) {
    map[TODO_LIST_ORDERING] = ordering;
  }
  return map;
}

TodoList _todoListFromRepresentation(Map<String, dynamic> representation) {
  return TodoList(
    representation[TODO_LIST_NAME],
    id: representation[ID],
  );
}

Future<void> createDatabase(Database db, int version) async {
  await db.transaction((txn) async {
    txn.execute("""
      create table $TODO_LISTS_TABLE (
        $ID integer primary key,
        $TODO_LIST_NAME text,
        $TODO_LIST_ORDERING integer
      );
    """);
    txn.execute("""
      create table $TODO_ITEMS_TABLE (
        $ID integer primary key,
        $TODO_ITEM_NAME text,
        $TODO_ITEM_COMPLETED tinyint,
        $TODO_ITEM_PRIORITY tinyint,
        $TODO_ITEM_NOTE text,
        $TODO_ITEM_DUE_DATE text,
        $TODO_ITEM_CREATED_DATE text,
        $TODO_ITEM_COMPLETED_DATE text
      );
    """);
    txn.execute("""
      create table $TODO_LIST_ITEMS_TABLE (
        $TODO_LIST_ITEMS_LIST integer references $TODO_LISTS_TABLE ($ID),
        $TODO_LIST_ITEMS_ITEM integer references $TODO_ITEMS_TABLE ($ID),
        $TODO_LIST_ITEMS_ORDERING integer
      );
    """);
    txn.execute("""
      create table $TODO_REMINDERS_TABLE (
        $ID integer primary key,
        $TODO_REMINDER_ITEM integer references $TODO_LIST_ITEMS_TABLE ($ID),
        $TODO_REMINDER_TIME text
      );
     """);
  });
}

Future<List<DateTime>> _getReminders(Database db, int itemId) async {
  var results = await db.query(TODO_REMINDERS_TABLE,
      columns: [TODO_REMINDER_TIME],
      where: "$TODO_REMINDER_ITEM = ?",
      whereArgs: [itemId]);
  return results.map((m) => DateTime.parse(m[TODO_REMINDER_TIME])).toList();
}

class _ItemsQuery {
  final int listId;
  final bool onList;
  final String where;
  final List<String> whereArgs;
  final String ordering;
  final String orderingDirection;
  final int offset;
  final String amount;

  _ItemsQuery({this.listId, filter: TodoStatusFilter.all, ordering: TodoListOrdering.custom, direction: TodoListOrderingDirection.ascending, this.offset=0, int limit}):
      onList = listId != null,
      where = buildWhere(filter),
      whereArgs = buildWhereArgs(filter),
      ordering = buildOrdering(listId, ordering),
      orderingDirection = buildOrderingDirection(direction),
      amount = buildAmount(offset, limit);

  Future<int> getNumberOfItems(Database db) async {
    String resultColumns = "count($ID)";
    var results = await query(db, resultColumns);
    if (results.isEmpty) {
      return 0;
    } else {
      return results.first[resultColumns] ?? 0;
    }
  }
  Future<List<int>> getTodoItems(Database db) async {
    String resultColumns = ID;
    var results = await query(db, resultColumns);
    return results.map((m) => m[resultColumns] as int).toList();
  }
  Future<List<TodoItem>> getChunkOfTodoItems(Database db) async {
    print("CHUNK: $where");
    String resultColumns = [
      ID,
      TODO_ITEM_NAME,
      TODO_ITEM_COMPLETED,
      TODO_ITEM_PRIORITY,
      TODO_ITEM_NOTE,
      TODO_ITEM_DUE_DATE,
      TODO_ITEM_CREATED_DATE,
      TODO_ITEM_COMPLETED_DATE
    ].join(", ");
    var results = await query(db, resultColumns);
    List<TodoItem> items = [];
    for (final result in results) {
      var id = result[ID];
      var reminders = await _getReminders(db, id);
//      List<DateTime> reminders = [];
      items.add(_todoItemFromRepresentation(result, reminders));
    }
    return items;
  }

  Future<List<Map<String,dynamic>>> query(Database db, String resultColumns) async {
    if (onList) {
      return await db.rawQuery("""
               select $resultColumns
                 from $TODO_ITEMS_TABLE
                 join $TODO_LIST_ITEMS_TABLE
                   on $ID = $TODO_LIST_ITEMS_ITEM
                where $TODO_LIST_ITEMS_LIST = ? and $where
             order by $ordering $orderingDirection
                      $amount;
        """, [listId.toString()]+whereArgs);
    } else {
      return await db.rawQuery("""
               select ($resultColumns)
                 from $TODO_ITEMS_TABLE
                where $where
             order by $ordering $orderingDirection
                      $amount; 
        """, whereArgs);
    }
  }

  static String buildWhere(TodoStatusFilter filter){
    String whereBuild;
    switch (filter) {
        case TodoStatusFilter.all:
          break;
        case TodoStatusFilter.active:
          whereBuild = "$TODO_ITEM_COMPLETED = 0";
          break;
        case TodoStatusFilter.completed:
          whereBuild = "$TODO_ITEM_COMPLETED = 1";
          break;
        case TodoStatusFilter.important:
          whereBuild =
          "$TODO_ITEM_COMPLETED = 0 and $TODO_ITEM_PRIORITY = ${TodoPriority.high.index}";
          break;
        case TodoStatusFilter.withDueDate:
          whereBuild =
          "$TODO_ITEM_COMPLETED = 0 and $TODO_ITEM_DUE_DATE is not null";
          break;
    }
    return whereBuild;
  }
  static List<String> buildWhereArgs(TodoStatusFilter filter) {
    List<String> whereArgsBuild = [];
    return whereArgsBuild;
  }
  static String buildOrdering(int listId, TodoListOrdering ordering) {
    var order = (listId == null && ordering == TodoListOrdering.custom) ? TodoListOrdering.byDate : ordering;
    switch (order) {
      case TodoListOrdering.custom: return TODO_LIST_ITEMS_ORDERING;
      case TodoListOrdering.byDate: return TODO_ITEM_CREATED_DATE;
      case TodoListOrdering.alphabetical: return TODO_ITEM_NAME;
      default: throw "BUG: Unhandled ordering of todo items!";
    }
  }
  static String buildOrderingDirection(TodoListOrderingDirection direction) {
    switch (direction) {
      case TodoListOrderingDirection.ascending: return "asc";
      case TodoListOrderingDirection.descending: return "dsc";
      default: throw "BUG: Unhandled ordering direction for todo items!";
    }
  }
  static String buildAmount(int offset, int limit) {
    print("READ: $offset, $limit");
    var amount = "";
    if (limit != null) {
      amount += " limit $limit";
    }
    if (offset != 0) {
      amount += " offset $offset ";
    }
    return amount;
  }
}