import 'package:qunderlist/notification_ffi.dart';
import 'package:qunderlist/repository/repository.dart';

Future<void> setRemindersForItem<R extends TodoRepository>(TodoItemBase item, R repository) async {
  List<Reminder> reminders;
  if (item is TodoItem) {
    reminders = item.reminders;
  } else {
    reminders = await repository.getRemindersForItem(item.id);
  }
  for (final r in reminders) {
    await NotificationFFI.setReminder(r);
  }
}

Future<void> cancelRemindersForItem<R extends TodoRepository>(TodoItemBase item, R repository) async {
  List<Reminder> reminders;
  if (item is TodoItem) {
    reminders = item.reminders;
  } else {
    reminders = await repository.getRemindersForItem(item.id);
  }
  for (final r in reminders) {
    await NotificationFFI.cancelReminder(r.id);
  }
}

Future<void> cancelRemindersForList<R extends TodoRepository>(TodoList list, R repository) async {
  var reminders = await repository.getActiveRemindersForList(list.id);
  for (final reminder in reminders) {
    await NotificationFFI.cancelReminder(reminder.id);
  }
}