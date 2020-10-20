import 'dart:async';

import 'package:qunderlist/repository/models.dart';

class ExternalUpdate {

}

abstract class TodoRepository {
  bool _streamActive;
  StreamController<ExternalUpdate> _updateStream;

  TodoRepository() {
    _updateStream = StreamController.broadcast(onListen: () => _streamActive=true, onCancel: () => _streamActive=false);
  }

  void triggerUpdate() {
    if (_streamActive) {
      _updateStream.add(ExternalUpdate());
    }
  }

  Stream<ExternalUpdate> get updateStream => _updateStream.stream;

  void dispose() {
    _updateStream.close();
  }


  // Functions accessing lists
  Future<int> addTodoList(TodoList list);
  Future<void> updateTodoList(TodoList list);
  Future<void> deleteTodoList(int listId);
  Future<void> moveTodoList(int listId, int moveTo);
  Future<TodoList> getTodoList(int id);
  Future<TodoList> getTodoListByName(String name);
  Future<int> getNumberOfTodoLists();
  Future<List<TodoList>> getTodoListsChunk(int start, int end);
  Future<List<TodoList>> getMatchingLists(String pattern, {int limit=5});

  // Functions accessing items
  Future<void> updateTodoItem(TodoItemBase item);
  Future<void> deleteTodoItem(int itemId);
  Future<TodoItem> getTodoItem(int id);

  // Function accessing reminders
  Future<int> addReminder(int itemId, DateTime at);
  Future<void> updateReminder(int reminderId, DateTime at);
  Future<void> deleteReminder(int reminderId);
  Future<List<Reminder>> getRemindersForItem(int itemId);
  Future<List<Reminder>> getActiveRemindersForList(int listId);
  Future<List<Reminder>> getActiveReminders();
  Future<int> getItemOfReminder(int reminderId);

  // Functions accessing items in lists
  Future<TodoItem> addTodoItem(TodoItem item, {TodoList onList});
  Future<void> addTodoItemToList(int itemId, int listId);
  Future<void> removeTodoItemFromList(int itemId, int listId);
  Future<void> moveTodoItemToList(int itemId, int oldListId, int newListId);
  Future<void> moveTodoItemInList(int itemId, int listId, int moveToId);
  Future<int> getNumberOfTodoItems(int listId, TodoStatusFilter filter);
  Future<List<TodoItemShort>> getTodoItemsOfListChunk(int listId, int start, int end, TodoStatusFilter filter);
  Future<List<TodoList>> getListsOfItem(int itemId);
}