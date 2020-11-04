import 'package:qunderlist/blocs/todo_details.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/blocs/todo_lists.dart';

class BaseState {
  final int listId;
  final int itemId;
  final TodoListsBloc listsBloc;
  final TodoListBloc listBloc;
  final TodoDetailsBloc itemBloc;

  BaseState(this.listId, this.itemId, this.listsBloc, this.listBloc, this.itemBloc);
}