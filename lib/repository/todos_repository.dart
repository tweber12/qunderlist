import 'package:qunderlist/repository/models.dart';

abstract class TodoRepository {
  // Functions accessing lists
  Future<int> addTodoList(TodoList list);
  Future<void> updateTodoList(TodoList list);
  Future<void> deleteTodoList(int listId);
  Future<void> moveTodoList(int listId, int moveTo);
  Future<TodoList> getTodoList(int id);
  Future<int> getNumberOfTodoLists();
  Future<List<TodoList>> getTodoListsChunk(int start, int end);

  // Functions accessing items
  Future<void> updateTodoItem(TodoItem item);
  Future<void> deleteTodoItem(int itemId);
  Future<TodoItem> getTodoItem(int id);

  // Function accessing reminders
  Future<int> addReminder(int itemId, DateTime at);
  Future<void> updateReminder(int reminderId, DateTime at);
  Future<void> deleteReminder(int reminderId);

  // Functions accessing items in lists
  Future<int> addTodoItem(TodoItem item, int listId);
  Future<void> addTodoItemToList(int itemId, int listId);
  Future<void> removeTodoItemFromList(int itemId, int listId);
  Future<void> moveTodoItemToList(int itemId, int oldListId, int newListId);
  Future<void> moveTodoItemInList(int itemId, int listId, int moveToId);
  Future<int> getNumberOfTodoItems(int listId, TodoStatusFilter filter);
  Future<List<TodoItem>> getTodoItemsOfListChunk(int listId, int start, int end, TodoStatusFilter filter);
  Future<List<TodoList>> getListsOfItem(int itemId);
}