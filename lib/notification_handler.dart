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

import 'blocs/repeated.dart';

const int PENDING_ITEM_CREATE_PREFIX = 1<<30;
const int PENDING_ITEM_NOTIFICATION_PREFIX = 1<<31;

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

Future<void> setPendingItem<R extends TodoRepository>(TodoItem basis, R repository, {TodoItem next}) async {
  if (next == null) {
    if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance == false) {
      return;
    }
    next = nextItem(basis);
  }
  setRemindersForPendingItem(basis, next, repository);
  NotificationFFI.setPendingItemAlarm(basis.id & PENDING_ITEM_CREATE_PREFIX, basis.id, _dateForPendingItemCreation(basis, next));
}

Future<void> cancelPendingItem<R extends TodoRepository>(TodoItem basis, R repository, {TodoItem next}) async {
  if (next == null) {
    if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance == false) {
      return;
    }
    next = nextItem(basis);
  }
  cancelRemindersForPendingItem(basis, repository);
  NotificationFFI.cancelPendingItemAlarm(basis.id & PENDING_ITEM_CREATE_PREFIX);
}

DateTime _dateForPendingItemCreation(TodoItem basis, TodoItem next) {
  var dayAfter = DateTime(basis.dueDate.year, basis.dueDate.month, basis.dueDate.day+1);
  if (next.reminders.isEmpty) {
    return dayAfter;
  }
  next.reminders.sort((a,b) => a.at.compareTo(b.at));
  var firstReminder = next.reminders.first.at;
  var date;
  if (dayAfter.isBefore(firstReminder)) {
    return dayAfter;
  } else {
    return DateTime(firstReminder.year, firstReminder.month, firstReminder.day);
  }
}

Future<void> setRemindersForPendingItem<R extends TodoRepository>(TodoItem basis, TodoItem next, R repository) async {
  if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance != true) {
    return;
  }
  for (int i=0; i<basis.reminders.length; i++) {
    var oldReminder = basis.reminders[i];
    var newReminder = next.reminders[i];
    await NotificationFFI.updateReminder(next, newReminder.withId(oldReminder.id & PENDING_ITEM_NOTIFICATION_PREFIX));
  }
}

Future<void> cancelRemindersForPendingItem<R extends TodoRepository>(TodoItem basis, R repository) async {
  if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance != true) {
    return;
  }
  for (final r in basis.reminders) {
    await NotificationFFI.cancelReminder(r.id & PENDING_ITEM_NOTIFICATION_PREFIX);
  }
}

Future<void> replaceRemindersForPendingItem<R extends TodoRepository>(TodoItem basis, TodoItem next, R repository) async {
  if (basis.repeatedStatus != RepeatedStatus.active || basis.repeated.autoAdvance != true) {
    return;
  }
  for (int i=0; i<basis.reminders.length; i++) {
    var oldReminder = basis.reminders[i];
    var newReminder = next.reminders[i];
    if (newReminder.at.isBefore(DateTime.now())) {
      await NotificationFFI.updateReminder(next, newReminder.withId(oldReminder.id & PENDING_ITEM_NOTIFICATION_PREFIX));
    } else {
      await NotificationFFI.cancelReminder(oldReminder.id & PENDING_ITEM_NOTIFICATION_PREFIX);
      await NotificationFFI.setReminder(next, newReminder);
    }
  }
}