import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/repository/models.dart';

void main() {
  group("list", () {
    test("withId", () {
      var list = TodoList("test", Palette.pink);
      var expected = TodoList("test", Palette.pink, id: 8);
      expect(list.withId(8), expected);
    });
  });

  group("item", () {
    var id = 8;
    var title = "test item";
    var note = "test\n\nnote";
    var createdOn = DateTime.now();
    var completedOn = createdOn.add(Duration(days: 3));
    var priority = TodoPriority.low;
    var dueDate = createdOn.subtract(Duration(hours: 5));
    var reminders = [Reminder(DateTime.now().add(Duration(days: 3))), Reminder(DateTime.now().add(Duration(minutes: 15))), Reminder(DateTime.now().subtract(Duration(days: 1)))];
    var lists = [TodoList("l1", Palette.pink, id: 1), TodoList("l3", Palette.green, id: 3)];
    var repeat = Repeated(true, false, false, true, RepeatedStepDaily(2));

    test("copyWith title", () {
      var newTitle = "new item name";
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(todo: newTitle);
      var expected = TodoItem(newTitle, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith createdOn", () {
      var newCreatedOn = createdOn.add(Duration(minutes: 3));
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(createdOn: newCreatedOn);
      var expected = TodoItem(title, newCreatedOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith id", () {
      var newId = id+3;
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(id: newId);
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: newId, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith completedOn", () {
      var newCompletedOn = completedOn.add(Duration(hours: 3));
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(completedOn: Nullable(newCompletedOn));
      var expected = TodoItem(title, createdOn, completedOn: newCompletedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith completedOn null", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(completedOn: Nullable(null));
      var expected = TodoItem(title, createdOn, completedOn: null, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith priority", () {
      var newPriority = TodoPriority.high;
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(priority: newPriority);
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: newPriority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith note", () {
      var newNote = "set\na\tnew\nnote";
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(note: Nullable(newNote));
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: newNote, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith note null", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(note: Nullable(null));
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: null, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith dueDate", () {
      var newDueDate = dueDate.add(Duration(minutes: 3));
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(dueDate: Nullable(newDueDate));
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: newDueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith dueDate null", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(dueDate: Nullable(null));
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: null, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith reminders", () {
      var newReminders = [Reminder(DateTime.now().add(Duration(seconds: 1))), Reminder(DateTime.now().subtract(Duration(seconds: 1)))];
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(reminders: newReminders);
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: newReminders, onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith reminders empty", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(reminders: []);
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: [], onLists: lists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith onLists", () {
      var newLists = [TodoList("9", Palette.yellow, id: 3)];
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(onLists: newLists);
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: newLists, id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith onLists empty", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(onLists: []);
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: [], id: id, repeated: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith repeated", () {
      var newRepeat = Repeated(false, true, true, false, RepeatedStepWeekly(3));
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(repeated: Nullable(newRepeat));
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: newRepeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith repeated null", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: repeat);
      var newItem = item.copyWith(repeated: Nullable(null));
      var expected = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, onLists: lists, id: id, repeated: null);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("completed", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: repeat);
      expect(item.completed, true);
    });

    test("not completed", () {
      var item = TodoItem(title, createdOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: repeat);
      expect(item.completed, false);
    });

    test("nActiveReminders", () {
      var item = TodoItem(title, createdOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: repeat);
      expect(item.nActiveReminders, 2);
    });

    test("repeatedStatus active", () {
      var item = TodoItem(title, createdOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: repeat);
      expect(item.repeatedStatus, RepeatedStatus.active);
    });

    test("repeatedStatus active", () {
      var newRepeat = Repeated(false, false, false, false, RepeatedStepDaily(5));
      var item = TodoItem(title, createdOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: newRepeat);
      expect(item.repeatedStatus, RepeatedStatus.inactive);
    });

    test("repeatedStatus none", () {
      var item = TodoItem(title, createdOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: null);
      expect(item.repeatedStatus, RepeatedStatus.none);
    });

    test("shorten", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: repeat);
      var short = item.shorten();
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: 2, id: id, repeatedStatus: RepeatedStatus.active);
      expect(short, expected);
    });

    test("toggleCompleted active", () {
      var item = TodoItem(title, createdOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: repeat);
      var newItem = item.toggleCompleted();
      expect(newItem.completed, true);
      expect(newItem, item.copyWith(completedOn: Nullable(newItem.completedOn)));
    });

    test("toggleCompleted completed", () {
      var item = TodoItem(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, reminders: reminders, id: id, repeated: repeat);
      var newItem = item.toggleCompleted();
      expect(newItem.completed, false);
      expect(newItem, item.copyWith(completedOn: Nullable(null)));
    });
  });

  group("item short", () {
    var id = 8;
    var title = "test item";
    var note = "test\n\nnote";
    var createdOn = DateTime.now();
    var completedOn = createdOn.add(Duration(days: 3));
    var priority = TodoPriority.low;
    var dueDate = createdOn.subtract(Duration(hours: 5));
    var nActiveReminders = 2;
    var repeat = RepeatedStatus.inactive;

    test("copyWith title", () {
      var newTitle = "new item name";
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(todo: newTitle);
      var expected = TodoItemShort(newTitle, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith createdOn", () {
      var newCreatedOn = createdOn.add(Duration(minutes: 3));
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(createdOn: newCreatedOn);
      var expected = TodoItemShort(title, newCreatedOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith id", () {
      var newId = id+3;
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(id: newId);
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: newId, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith completedOn", () {
      var newCompletedOn = completedOn.add(Duration(hours: 3));
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(completedOn: Nullable(newCompletedOn));
      var expected = TodoItemShort(title, createdOn, completedOn: newCompletedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith completedOn null", () {
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(completedOn: Nullable(null));
      var expected = TodoItemShort(title, createdOn, completedOn: null, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith priority", () {
      var newPriority = TodoPriority.high;
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(priority: newPriority);
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: newPriority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith note", () {
      var newNote = "set\na\tnew\nnote";
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(note: Nullable(newNote));
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: newNote, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith note null", () {
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(note: Nullable(null));
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: null, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith dueDate", () {
      var newDueDate = dueDate.add(Duration(minutes: 3));
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(dueDate: Nullable(newDueDate));
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: newDueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith dueDate null", () {
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(dueDate: Nullable(null));
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: null, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith nActiveReminders", () {
      var newReminders = nActiveReminders+32;
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(nActiveReminders: newReminders);
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: newReminders, id: id, repeatedStatus: repeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("copyWith repeatedStatus", () {
      var newRepeat = RepeatedStatus.active;
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.copyWith(repeatedStatus: newRepeat);
      var expected = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: newRepeat);
      expect(newItem, expected);
      expect(newItem, isNot(item));
    });

    test("completed", () {
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(item.completed, true);
    });

    test("not completed", () {
      var item = TodoItemShort(title, createdOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(item.completed, false);
    });

    test("nActiveReminders", () {
      var item = TodoItemShort(title, createdOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(item.nActiveReminders, nActiveReminders);
    });

    test("repeatedStatus", () {
      var item = TodoItemShort(title, createdOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(item.repeatedStatus, repeat);
    });

    test("shorten", () {
      var item = TodoItemShort(title, createdOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      expect(item.shorten(), item);
    });

    test("toggleCompleted active", () {
      var item = TodoItemShort(title, createdOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.toggleCompleted();
      expect(newItem.completed, true);
      expect(newItem, item.copyWith(completedOn: Nullable(newItem.completedOn)));
    });

    test("toggleCompleted completed", () {
      var item = TodoItemShort(title, createdOn, completedOn: completedOn, priority: priority, note: note, dueDate: dueDate, nActiveReminders: nActiveReminders, id: id, repeatedStatus: repeat);
      var newItem = item.toggleCompleted();
      expect(newItem.completed, false);
      expect(newItem, item.copyWith(completedOn: Nullable(null)));
    });
  });

  group("reminder", () {
    var time = DateTime.now();
    var id = 3;

    test("withId", () {
      var newId = 8;
      var reminder = Reminder(time, id: id);
      var newReminder = reminder.withId(newId);
      var expected = Reminder(time, id: newId);
      expect(newReminder, expected);
      expect(newReminder, isNot(reminder));
    });

    test("copyWith at", () {
      var newTime = time.add(Duration(minutes: 3));
      var reminder = Reminder(time, id: id);
      var newReminder = reminder.copyWith(at: newTime);
      var expected = Reminder(newTime, id: id);
      expect(newReminder, expected);
      expect(newReminder, isNot(reminder));
    });
  });

  group("repeated", () {
    var active = true;
    var autoAdvance = false;
    var autoComplete = false;
    var keepHistory = true;
    var step = RepeatedStepDaily(1);

    // The 'neg' and 'shuffled' tests are there because for the four bools there's no type
    // safety and it's impossible to use four different values to ensure that the values
    // aren't assigned to the wrong one. Therefore do tests with negated or switched values
    // to break these degeneracies.

    test("copyWith active", () {
      var repeated = Repeated(active, autoAdvance, autoComplete, keepHistory, step);
      var newRepeated = repeated.copyWith(active: !active);
      var expected = Repeated(!active, autoAdvance, autoComplete, keepHistory, step);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("copyWith active neg", () {
      var repeated = Repeated(active, !autoAdvance, !autoComplete, !keepHistory, step);
      var newRepeated = repeated.copyWith(active: !active);
      var expected = Repeated(!active, !autoAdvance, !autoComplete, !keepHistory, step);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("copyWith autoAdvance", () {
      var repeated = Repeated(active, autoAdvance, autoComplete, keepHistory, step);
      var newRepeated = repeated.copyWith(autoAdvance: !autoAdvance);
      var expected = Repeated(active, !autoAdvance, autoComplete, keepHistory, step);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("copyWith autoAdvance neg", () {
      var repeated = Repeated(!active, autoAdvance, !autoComplete, !keepHistory, step);
      var newRepeated = repeated.copyWith(autoAdvance: !autoAdvance);
      var expected = Repeated(!active, !autoAdvance, !autoComplete, !keepHistory, step);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("copyWith autoComplete", () {
      var repeated = Repeated(active, autoAdvance, autoComplete, keepHistory, step);
      var newRepeated = repeated.copyWith(autoComplete: !autoComplete);
      var expected = Repeated(active, autoAdvance, !autoComplete, keepHistory, step);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("copyWith autoComplete neg", () {
      var repeated = Repeated(!active, !autoAdvance, autoComplete, !keepHistory, step);
      var newRepeated = repeated.copyWith(autoComplete: !autoComplete);
      var expected = Repeated(!active, !autoAdvance, !autoComplete, !keepHistory, step);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("copyWith keepHistory", () {
      var repeated = Repeated(active, autoAdvance, autoComplete, keepHistory, step);
      var newRepeated = repeated.copyWith(keepHistory: !keepHistory);
      var expected = Repeated(active, autoAdvance, autoComplete, !keepHistory, step);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("copyWith keepHistory neg", () {
      var repeated = Repeated(!active, !autoAdvance, !autoComplete, keepHistory, step);
      var newRepeated = repeated.copyWith(keepHistory: !keepHistory);
      var expected = Repeated(!active, !autoAdvance, !autoComplete, !keepHistory, step);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("copyWith nothing", () {
      var repeated = Repeated(active, autoAdvance, autoComplete, keepHistory, step);
      var newRepeated = repeated.copyWith();
      expect(newRepeated, repeated);
    });

    test("copyWith nothing shuffled 1", () {
      var repeated = Repeated(active, autoAdvance, !autoComplete, !keepHistory, step);
      var newRepeated = repeated.copyWith();
      expect(newRepeated, repeated);
    });

    test("copyWith nothing shuffled 2", () {
      var repeated = Repeated(active, !autoAdvance, autoComplete, !keepHistory, step);
      var newRepeated = repeated.copyWith();
      expect(newRepeated, repeated);
    });

    test("copyWith step", () {
      var newStep = RepeatedStepWeekly(4);
      var repeated = Repeated(active, autoAdvance, autoComplete, keepHistory, step);
      var newRepeated = repeated.copyWith(step: newStep);
      var expected = Repeated(active, autoAdvance, autoComplete, keepHistory, newStep);
      expect(newRepeated, expected);
      expect(newRepeated, isNot(repeated));
    });

    test("set amount daily", () {
      var step = RepeatedStepDaily(1);
      expect(step.withAmount(5), RepeatedStepDaily(5));
    });

    test("set amount weekly", () {
      var step = RepeatedStepWeekly(1);
      expect(step.withAmount(5), RepeatedStepWeekly(5));
    });

    test("set amount monthly", () {
      var step = RepeatedStepMonthly(1,12);
      expect(step.withAmount(5), RepeatedStepMonthly(5,12));
    });

    test("set amount yearly", () {
      var step = RepeatedStepYearly(1,3,27);
      expect(step.withAmount(5), RepeatedStepYearly(5,3,27));
    });
  });
}