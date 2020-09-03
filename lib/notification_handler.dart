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
  Api().setReminder(r);
}

Future<bool> cancelReminder(Reminder reminder) {
  var r = DeleteReminder()..reminderId=reminder.id;
  Api().deleteReminder(r);
}

Future<List<bool>> setRemindersForItem(TodoItem item) {
  return Future.wait(item.reminders.map(setReminder));
}

Future<List<bool>> cancelRemindersForItem(TodoItem item) {
  return Future.wait(item.reminders.map(cancelReminder));
}

Future<void> cancelRemindersForList<R extends TodoRepository>(TodoList list, R repository) async {
  var totalLength = await repository.getNumberOfTodoItems(list.id, TodoStatusFilter.active);
  Future<List<TodoItem>> underlyingData(int start, int end) {
    return repository.getTodoItemsOfListChunk(list.id, start, end, TodoStatusFilter.active);
  }
  var cache = ListCache(underlyingData, totalLength);
  for (int i=0; i<totalLength; i++) {
    var item = await cache.getItem(i);
    var nLists = (await repository.getListsOfItem(item.id)).length;
    if (nLists > 1) {
      return;
    }
    cancelRemindersForItem(item);
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

  void notificationCallback(ItemId id) {
    showItem(id.id);
  }
}