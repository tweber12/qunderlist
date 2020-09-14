import 'package:qunderlist/repository/models.dart';
import 'package:sqflite/sqflite.dart';

const String ID = "id";

const String TODO_LISTS_TABLE = "todo_lists";
const String TODO_LIST_NAME = "list_name";
const String TODO_LIST_COLOR = "list_color";
const String TODO_LIST_ORDERING = "list_ordering";

const String TODO_ITEMS_TABLE = "todo_items";
const String TODO_ITEM_NAME = "item_name";
const String TODO_ITEM_PRIORITY = "item_priority";
const String TODO_ITEM_NOTE = "item_note";
const String TODO_ITEM_DUE_DATE = "item_due";
const String TODO_ITEM_REPEAT = "item_repeat";
const String TODO_ITEM_CREATED_DATE = "item_created_date";
const String TODO_ITEM_COMPLETED_DATE = "item_completed_date";

const String TODO_LIST_ITEMS_TABLE = "todo_list_items";
const String TODO_LIST_ITEMS_LIST = "list_items_list";
const String TODO_LIST_ITEMS_ITEM = "list_items_item";
const String TODO_LIST_ITEMS_ORDERING = "list_items_ordering";

const String TODO_REMINDERS_TABLE = "todo_reminders";
const String TODO_REMINDER_ITEM = "reminder_item";
const String TODO_REMINDER_TIME = "reminder_time";
const String TODO_REMINDER_REPEAT = "reminder_repeat";

const String TODO_LIST_ITEMS_ORDERING_INDEX = "todo_list_items_ordering_index";
const String TODO_REMINDER_INDEX = "todo_reminder_index";

const String ORPHAN_ITEMS_TRIGGER = "orphan_items_trigger";

Future<void> createDatabase(Database db, int version) async {
  await db.transaction((txn) async {
    txn.execute("""
      create table $TODO_LISTS_TABLE (
        $ID integer primary key,
        $TODO_LIST_NAME text,
        $TODO_LIST_COLOR tinyint,
        $TODO_LIST_ORDERING integer unique
      );
    """);
    txn.execute("""
      create table $TODO_ITEMS_TABLE (
        $ID integer primary key,
        $TODO_ITEM_NAME text,
        $TODO_ITEM_PRIORITY tinyint,
        $TODO_ITEM_NOTE text,
        $TODO_ITEM_DUE_DATE text,
        $TODO_ITEM_REPEAT text,
        $TODO_ITEM_CREATED_DATE text,
        $TODO_ITEM_COMPLETED_DATE text
      );
    """);
    txn.execute("""
      create table $TODO_LIST_ITEMS_TABLE (
        $TODO_LIST_ITEMS_LIST integer references $TODO_LISTS_TABLE ($ID) on update cascade on delete cascade,
        $TODO_LIST_ITEMS_ITEM integer references $TODO_ITEMS_TABLE ($ID) on update cascade on delete cascade,
        $TODO_LIST_ITEMS_ORDERING integer
      );
    """);
    txn.execute("""
      create unique index $TODO_LIST_ITEMS_ORDERING_INDEX on $TODO_LIST_ITEMS_TABLE ($TODO_LIST_ITEMS_LIST, $TODO_LIST_ITEMS_ORDERING)
      """);
    txn.execute("""
        create trigger $ORPHAN_ITEMS_TRIGGER
       after delete on $TODO_LIST_ITEMS_TABLE
                  when not exists (
                         select 1 from $TODO_LIST_ITEMS_TABLE
                         where $TODO_LIST_ITEMS_ITEM=old.$TODO_LIST_ITEMS_ITEM
                       )
                 begin
                       delete from $TODO_REMINDERS_TABLE
                             where $TODO_REMINDER_ITEM = old.$TODO_LIST_ITEMS_ITEM;
                       delete from $TODO_ITEMS_TABLE
                             where $ID = old.$TODO_LIST_ITEMS_ITEM;
                   end
      """);
    txn.execute("""
      create table $TODO_REMINDERS_TABLE (
        $ID integer primary key,
        $TODO_REMINDER_ITEM integer references $TODO_ITEMS_TABLE ($ID) on update cascade on delete cascade,
        $TODO_REMINDER_TIME text,
        $TODO_REMINDER_REPEAT text
      );
     """);
    txn.execute("""
      create index $TODO_REMINDER_INDEX on $TODO_REMINDERS_TABLE ($TODO_REMINDER_ITEM, $TODO_REMINDER_TIME, $ID);
      """);
  });
}

Future<void> configureDatabase(Database db) {
  return db.execute("""pragma foreign_keys = on""");
}

TodoList todoListFromRepresentation(Map<String, dynamic> representation) {
  return TodoList(
    representation[TODO_LIST_NAME],
    Palette.values[representation[TODO_LIST_COLOR]],
    id: representation[ID],
  );
}

Map<String, dynamic> todoListToRepresentation(TodoList list, {int ordering}) {
  Map<String,dynamic> map = {
    TODO_LIST_NAME: list.listName,
    TODO_LIST_COLOR: list.color.index,
  };
  if (ordering != null) {
    map[TODO_LIST_ORDERING] = ordering;
  }
  return map;
}

Map<String, dynamic> todoItemToRepresentation(TodoItemBase item) {
  var map = {
    TODO_ITEM_NAME: item.todo,
    TODO_ITEM_PRIORITY: item.priority.index,
    TODO_ITEM_NOTE: item.note,
    TODO_ITEM_DUE_DATE: item.dueDate?.toIso8601String(),
    TODO_ITEM_CREATED_DATE: item.createdOn.toIso8601String(),
    TODO_ITEM_COMPLETED_DATE: item.completedOn?.toIso8601String(),
  };
  return map;
}

TodoItemShort todoItemShortFromRepresentation(
    Map<String, dynamic> representation, int nActiveReminders) {
  return TodoItemShort(
    representation[TODO_ITEM_NAME],
    DateTime.parse(representation[TODO_ITEM_CREATED_DATE]),
    id: representation[ID],
    priority: TodoPriority.values[representation[TODO_ITEM_PRIORITY]],
    note: representation[TODO_ITEM_NOTE],
    dueDate: representation[TODO_ITEM_DUE_DATE] == null
        ? null
        : DateTime.parse(representation[TODO_ITEM_DUE_DATE]),
    completedOn: representation[TODO_ITEM_COMPLETED_DATE] == null
        ? null
        : DateTime.parse(representation[TODO_ITEM_COMPLETED_DATE]),
    nActiveReminders: nActiveReminders,
  );
}

TodoItem todoItemFromRepresentation(
    Map<String, dynamic> representation, List<Reminder> reminders) {
  return TodoItem(
    representation[TODO_ITEM_NAME],
    DateTime.parse(representation[TODO_ITEM_CREATED_DATE]),
    id: representation[ID],
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

Reminder reminderFromRepresentation(Map<String,dynamic> representation) {
  return Reminder(DateTime.parse(representation[TODO_REMINDER_TIME]), id: representation[ID]);
}

Map<String,dynamic> reminderToRepresentation(Reminder reminder) {
  Map<String,dynamic> map = { TODO_REMINDER_TIME: reminder.at.toIso8601String() };
  if (reminder.id != null && reminder.id != 0) {
    map[ID] = reminder.id;
  }
  return map;
}