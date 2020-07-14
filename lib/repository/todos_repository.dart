import 'package:qunderlist/repository/models.dart';

abstract class TodoRepository {
  Future<void> addTodoItem(TodoItem item, int listId);
  Future<void> updateTodoItem(TodoItem item);
  Future<void> deleteTodoItem(TodoItem item);
  Stream<TodoItem> getTodoItem(int id);

  Future<void> addTodoList(TodoList list);
  Future<void> updateTodoList(TodoList list);
  Future<void> deleteTodoList(TodoList list);
  Future<void> moveList(TodoList list, int moveTo);
  Stream<TodoList> getTodoList(int id);
  Stream<List<int>> getTodoLists();
  Stream<List<int>> getTodoItemsOfList(int listId, {TodoStatusFilter filter});

  Future<void> addTodoItemToList(TodoItem item, int listId);
  Future<void> removeTodoItemFromList(TodoItem item, int listId);
  Future<void> moveTodoItemToList(TodoItem item, int oldListId, int newListId);
  Future<void> moveItemInList(TodoItem item, int listId, int moveTo);
  Future<void> moveItemToTopOfList(TodoItem item, int listId, {int offset});
  Future<void> moveItemToBottomOfList(TodoItem item, int listId, {int offset});
}