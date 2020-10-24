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
    await NotificationFFI.setReminder(item, r);
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