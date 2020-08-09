import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/repository.dart';

abstract class TodoDetailsState with EquatableMixin {
  final TodoItem item;
  TodoDetailsState(this.item);

  @override
  List<Object> get props => [item];

  @override
  bool get stringify => true;
}

class TodoDetailsLoadedItem extends TodoDetailsState {
  TodoDetailsLoadedItem(item): super(item);
}

class TodoDetailsFullyLoaded extends TodoDetailsState {
  final List<TodoList> lists;
  TodoDetailsFullyLoaded(item, this.lists): super(item);

  @override
  List<Object> get props => [item, ...lists];
}