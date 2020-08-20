import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/repository.dart';

abstract class TodoDetailsState with EquatableMixin {
  @override
  bool get stringify => true;
}

class TodoDetailsLoading extends TodoDetailsState {
  @override
  List<Object> get props => [];
}

class TodoDetailsLoadedItem extends TodoDetailsState {
  final TodoItem item;
  TodoDetailsLoadedItem(this.item);

  @override
  List<Object> get props => [item];
}

class TodoDetailsFullyLoaded extends TodoDetailsState {
  final TodoItem item;
  final List<TodoList> lists;
  TodoDetailsFullyLoaded(this.item, this.lists);

  @override
  List<Object> get props => [item, ...lists];
}