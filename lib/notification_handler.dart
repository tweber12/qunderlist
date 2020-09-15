import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/pigeon.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/screens/todo_item_screen.dart';
import 'package:qunderlist/screens/todo_list_screen.dart';

Future<bool> setReminder(Reminder reminder) {
  SetReminder r = SetReminder()
    ..reminderId = reminder.id
    ..time = reminder.at.millisecondsSinceEpoch;
  return Api().setReminder(r);
}

Future<bool> cancelReminder(Reminder reminder) {
  var r = DeleteReminder()..reminderId=reminder.id;
  return Api().deleteReminder(r);
}

Future<List<bool>> setRemindersForItem<R extends TodoRepository>(TodoItemBase item, R repository) async {
  if (item is TodoItem) {
    return Future.wait(item.reminders.map(setReminder));
  } else {
    var reminders = await repository.getRemindersForItem(item.id);
    return Future.wait(reminders.map(setReminder));
  }
}

Future<List<bool>> cancelRemindersForItem<R extends TodoRepository>(TodoItemBase item, R repository) async {
  if (item is TodoItem) {
    return Future.wait(item.reminders.map(cancelReminder));
  } else {
    var reminders = await repository.getRemindersForItem(item.id);
    return Future.wait(reminders.map(cancelReminder));
  }
}

Future<void> cancelRemindersForList<R extends TodoRepository>(TodoList list, R repository) async {
  var reminders = await repository.getActiveRemindersForList(list.id);
  for (final reminder in reminders) {
    cancelReminder(reminder);
  }
}

class Notifier extends DartApi {
  BuildContext context;
  Notifier(this.context);

  Future<void> showItem(int itemId) async {
    var repository = RepositoryProvider.of<TodoRepository>(context);
    var list = (await repository.getListsOfItem(itemId)).first;
    var bloc = TodoListBloc(repository, list, filter: TodoStatusFilter.active);
    bloc.add(GetDataEvent(filter: TodoStatusFilter.active));
    var navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) => showTodoListScreenExternal(context, repository, bloc)
        ),
            (route) => route.settings.name == "/"
    );
    navigator.push(
      MaterialPageRoute(
          builder: (context) => showTodoItemScreen(context, repository, itemId: itemId, todoListBloc: bloc)
      ),
    );
  }

  void reloadDb() async {
    var repository = RepositoryProvider.of<TodoRepository>(context);
    repository.triggerUpdate();
  }

  void notificationCallback(ItemId id) {
    showItem(id.id);
  }
}