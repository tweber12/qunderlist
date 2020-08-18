import 'package:qunderlist/repository/models.dart';

abstract class TodoRepository {
  Future<int> addTodoItem(TodoItem item, int listId);
  Future<void> completeTodoItem(TodoItem item);
  Future<void> updateTodoItem(TodoItem item);
  Future<void> deleteTodoItem(TodoItem item);
  Future<TodoItem> getTodoItem(int id);

  Future<void> addTodoList(TodoList list);
  Future<void> updateTodoList(TodoList list);
  Future<void> deleteTodoList(TodoList list);
  Future<void> moveList(TodoList list, int moveTo);
  Future<TodoList> getTodoList(int id);
  Future<int> getNumberOfTodoLists();
  Future<List<int>> getTodoLists();
  Future<List<TodoList>> getTodoListsChunk(int start, int end);
  Future<int> getNumberOfItems(int listId, {TodoStatusFilter filter});
  Future<List<int>> getTodoItemsOfList(int listId, {TodoStatusFilter filter});
  Future<List<TodoItem>> getTodoItemsOfListChunk(int listId, int start, int end, {TodoStatusFilter filter});
  Future<List<TodoList>> getListsOfItem(int itemId);

  Future<void> addTodoItemToList(TodoItem item, int listId);
  Future<void> removeTodoItemFromList(TodoItem item, int listId);
  Future<void> moveTodoItemToList(TodoItem item, int oldListId, int newListId);
  Future<void> moveItemInList(TodoItem item, int listId, int moveToId);
  Future<void> moveItemToTopOfList(TodoItem item, int listId, {int offset});
  Future<void> moveItemToBottomOfList(TodoItem item, int listId, {int offset});
}